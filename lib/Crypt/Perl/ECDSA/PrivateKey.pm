package Crypt::Perl::ECDSA::PrivateKey;

=encoding utf-8

=head1 NAME

Crypt::Perl::ECDSA::PrivateKey

=head1 SYNOPSIS

    #Use Generate.pm or Parse.pm rather
    #than instantiating this class directly.

    #This works even if the object came from a key file that doesn’t
    #contain the curve name.
    $prkey->get_curve_name();

    if ($payload > ($prkey->max_sign_bits() / 8)) {
        die "Payload too long!";
    }

    #$payload is probably a hash (e.g., SHA-256) of your original message.
    my $sig = $prkey->sign($payload);

    $prkey->verify($payload, $sig) or die "Invalid signature!";

    #Corresponding “der” methods exist as well.
    my $cn_pem = $prkey->to_pem_with_curve_name();
    my $expc_pem = $prkey->to_pem_with_explicit_curve();

    my $pbkey = $prkey->get_public_key();

=head1 DISCUSSION

The SYNOPSIS above should be illustration enough of how to use this class.

=head1 SECURITY

The security advantages of elliptic-curve cryptography (ECC) are a matter of
some controversy. While the math itself is apparently bulletproof, there are
varying opinions about the integrity of the various curves that are recommended
for ECC. Some believe that some curves contain “backdoors” that would allow
L<NIST|https://www.nist.gov> to sniff a transmission.

That said, RSA will eventually no longer be viable: as the keys get bigger, the
security advantage of increasing their size diminishes.

=head1 TODO

This minimal set of functionality can be augmented as feature requests come in.
Patches are welcome—particularly with tests!

=cut

use strict;
use warnings;

use parent qw( Crypt::Perl::ECDSA::KeyBase );

use Try::Tiny;

use Bytes::Random::Secure::Tiny ();
use Module::Load ();

use Crypt::Perl::ASN1 ();
use Crypt::Perl::BigInt ();
use Crypt::Perl::PKCS8 ();
use Crypt::Perl::RNG ();
use Crypt::Perl::Math ();
use Crypt::Perl::ToDER ();
use Crypt::Perl::X ();

#This is not the standard ASN.1 template as found in RFC 5915,
#but it seems to generate equivalent results.
#
use constant ASN1_PRIVATE => Crypt::Perl::ECDSA::KeyBase->ASN1_Params() . q<

    ECPrivateKey ::= SEQUENCE {
        version         INTEGER,
        privateKey      OCTET STRING,
        parameters      [0] EXPLICIT EcpkParameters OPTIONAL,
        publicKey       [1] EXPLICIT BIT STRING
    }
>;

use constant _PEM_HEADER => 'EC PRIVATE KEY';

#Expects $key_parts to be a hash ref:
#
#   version - AFAICT unused
#   private - BigInt or its byte-string representation
#   public  - ^^
#
sub new_by_curve_name {
    my ($class, $key_parts, $curve_name) = @_;

    #We could store the curve name on here if looking it up
    #in to_der_with_curve_name() proves prohibitive.
    return $class->new(
        $key_parts,

        #“Fake out” the $curve_parts attribute by recreating
        #the structure that ASN.1 would give from a named curve.
        {
            namedCurve => Crypt::Perl::ECDSA::EC::DB::get_oid_for_curve_name($curve_name),
        },
    );
}


#$curve_parts is also a hash ref, defined as whatever the ASN.1
#parse of the main key’s “parameters” returned, whether that be
#explicit key parameters or a named curve.
#
sub new {
    my ($class, $key_parts, $curve_parts) = @_;

    my $self = {
        version => $key_parts->{'version'},
    };

    for my $k ( qw( private public ) ) {
        if ( try { $key_parts->{$k}->isa('Crypt::Perl::BigInt') } ) {
            $self->{$k} = $key_parts->{$k};
        }
        else {
            die "“$k” must be “Crypt::Perl::BigInt”, not “$key_parts->{$k}”!";
        }
    }

    bless $self, $class;

    return $self->_add_params( $curve_parts );
}

#$whatsit is probably a message digest, e.g., from SHA256
sub sign {
    my ($self, $whatsit) = @_;

    my $dgst = Crypt::Perl::BigInt->from_bytes( $whatsit );

    my $priv_num = $self->{'private'}; #Math::BigInt->from_hex( $priv_hex );

    my $n = $self->_curve()->{'n'}; #$curve_data->{'n'};

    my $key_len = $self->max_sign_bits();
    my $dgst_len = $dgst->bit_length();
    if ( $dgst_len > $key_len ) {
        die Crypt::Perl::X::create('TooLongToSign', $key_len, $dgst_len );
    }

    #isa ECPoint
    my $G = $self->_G();
#printf "G.x: %s\n", $G->{'x'}->to_bigint()->as_hex();
#printf "G.y: %s\n", $G->{'y'}->to_bigint()->as_hex();
#printf "G.z: %s\n", $G->{'z'}->as_hex();

    my ($k, $r);

    do {
        $k = Crypt::Perl::Math::randint($n);
#print "once\n";
#printf "big random: %s\n", $k->as_hex();
#$k = Crypt::Perl::BigInt->new("98452900523450592996995215574085435893040452563985855319633891614520662229711");
#printf "k: %s\n", $k->bstr();
        my $Q = $G->multiply($k);   #$Q isa ECPoint
#printf "Q.x: %s\n", $Q->{'x'}->to_bigint()->as_hex();
#printf "Q.y: %s\n", $Q->{'y'}->to_bigint()->as_hex();
#printf "Q.z: %s\n", $Q->{'z'}->as_hex();
        $r = $Q->get_x()->to_bigint()->bmod($n);
    } while ($r <= 0);

#printf "k: %s\n", $k->as_hex();
#printf "n: %s\n", $n->as_hex();
#printf "e: %s\n", $dgst->as_hex();
#printf "d: %s\n", $priv_num->as_hex();
#printf "r: %s\n", $r->as_hex();

    my $s = $k->bmodinv($n);
    $s *= ( $dgst + ( $priv_num * $r ) );
    $s %= $n;

    return $self->_serialize_sig( $r, $s );
}

sub get_public_key {
    my ($self) = @_;

    Module::Load::load('Crypt::Perl::ECDSA::PublicKey');

    return Crypt::Perl::ECDSA::PublicKey->new(
        $self->{'public'},
        $self->_explicit_curve_parameters(),
    );
}

#----------------------------------------------------------------------

sub _get_asn1_parts {
    my ($self, $curve_parts) = @_;

    my $private_str = $self->{'private'}->as_bytes();

    return $self->__to_der(
        'ECPrivateKey',
        ASN1_PRIVATE(),
        {
            version => 1,
            privateKey => $self->_pad_bytes_for_asn1($private_str),
            parameters => $curve_parts,
        },
    );
}

#Accepts der
#sub new {
#    my ($class, $der) = @_;
#
#    Crypt::Perl::ToDER::ensure_der($der);
#
#    my $asn1 = $class->_asn1();
#    my $asn1_ec = $asn1->find('ECPrivateKey');
#
#    my $struct;
#    try {
#        $struct = $asn1_ec->decode($der);
#    }
#    catch {
#        my $ec_err = $_;
#
#        my $asn1_pkcs8 = $asn1->find('PrivateKeyInfo');
#
#        try {
#            my $pk8_struct = $asn1_pkcs8->decode($der);
#
#            #It still might succeed, even if this is wrong, so don’t die().
#            if ( $pk8_struct->{'privateKeyAlgorithm'}{'algorithm'} ne $class->OID_ecPublicKey() ) {
#                warn "Unknown private key algorithm OID: “$pk8_struct->{'privateKeyAlgorithm'}{'algorithm'}”";
#            }
#
#            my $asn1_params = $asn1->find('EcpkParameters');
#            my $params = $asn1_params->decode($pk8_struct->{'privateKeyAlgorithm'}{'parameters'});
#
#            $struct = $asn1_ec->decode($pk8_struct->{'privateKey'});
#            $struct->{'parameters'} = $params;
#        }
#        catch {
#            die "Failed to decode private key as either ECDSA native ($ec_err) or PKCS8 ($_)";
#        };
#    };
#
#    my $self = {
#        version => $struct->{'version'},
#        private => Crypt::Perl::BigInt->from_bytes($struct->{'privateKey'}),
#        public => Crypt::Perl::BigInt->from_bytes($struct->{'publicKey'}[0]),
#
#        #for parsing
#        public_bytes_r => \$struct->{'publicKey'}[0],
#    };
##print "fieldType [$struct->{'parameters'}{'primeData'}{'fieldType'}]\n";
#
#    bless $self, $class;
#
#    $self->_add_params( $struct->{'parameters'} );
#
#    return $self;
#}

#could be faster; see JS implementation?
sub _getBigRandom {
    my ($limit) = @_;

    my $lim_bytes = length($limit->as_hex()) - 2;
    $lim_bytes /= 2;

    my $r;
    do {
        $r = Crypt::Perl::BigInt->from_hex( Crypt::Perl::RNG::bytes_hex($lim_bytes) );
    } while $r > $limit;

    return $r;
}

sub _serialize_sig {
    my ($self, $r, $s) = @_;

    my $asn1 = Crypt::Perl::ASN1->new()->prepare( $self->ASN1_SIGNATURE() );
    return $asn1->encode( r => $r, s => $s );
}

1;
