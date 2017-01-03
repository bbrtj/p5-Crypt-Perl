package OpenSSL_Control;

use strict;
use warnings;

use Test::More;

use Call::Context ();
use File::Temp ();
use File::Which ();
use IPC::Open3 ();
use Module::Load ();

use lib '../lib';

sub openssl_version {
    my $bin = openssl_bin();
    return scalar qx<$bin version -v -o -f>;
}

my $_ecdsa_test_err;
sub can_ecdsa {
    my ($self) = @_;

    if ( !defined $_ecdsa_test_err ) {
        my $bin = openssl_bin();

        if ($bin) {
            my $pid = IPC::Open3::open3( my $wtr, my $rdr, undef, "$bin ecparam -list_curves" );
            close $wtr;
            my $out = do { local $/; <$rdr> };
            close $rdr;
            waitpid $pid, 0;

            $_ecdsa_test_err = $?;

            #At least 0.9.8e doesn’t actually indicate error status on
            #an unrecognized command … grr.
            $_ecdsa_test_err ||= ($out !~ m<prime256v1>);
        }
        else {
            $_ecdsa_test_err = 'no openssl';
        }
    }

    return !$_ecdsa_test_err;
}

sub verify_private {
    my ($key_pem, $message, $digest_alg, $signature) = @_;

    my $openssl_bin = openssl_bin();

    my $dir = File::Temp::tempdir(CLEANUP => 1);

    open my $kfh, '>', "$dir/key";
    print {$kfh} $key_pem or die $!;
    close $kfh;

    open my $sfh, '>', "$dir/sig";
    print {$sfh} $signature or die $!;
    close $sfh;

    open my $mfh, '>', "$dir/msg";
    print {$mfh} $message or die $!;
    close $mfh;

    my $ver = qx<$openssl_bin dgst -$digest_alg -prverify $dir/key -signature $dir/sig $dir/msg>;
    my $ok = $ver =~ m<OK>;

    warn $ver if !$ok;

    return $ok;
}

sub curve_names {
    Call::Context::must_be_list();

    my $bin = openssl_bin();
    my @lines = qx<$bin ecparam -list_curves>;

    return map { m<(\S+)\s*:> ? $1 : () } @lines;
}

sub curve_oid {
    my ($name) = @_;

    my ($asn1, $out) = __ecparam( $name, 'named_curve', 'oid OBJECT IDENTIFIER' );
    return $asn1->decode($out)->{'oid'};
}

sub curve_data {
    my ($name) = @_;

    Module::Load::load('Crypt::Perl::ECDSA::ECParameters');

    my ($asn1, $out) = __ecparam( $name, 'explicit', Crypt::Perl::ECDSA::ECParameters::ASN1_ECParameters() );

    return $asn1->find('ECParameters')->decode($out);
}

sub __ecparam {
    my ($name, $param_enc, $asn1_template) = @_;

    Module::Load::load('Crypt::Perl::ASN1');

    my $bin = openssl_bin();
    my $out = qx<$bin ecparam -name $name -param_enc $param_enc -outform DER>;

    my $asn1 = Crypt::Perl::ASN1->new()->prepare($asn1_template);
    return ($asn1, $out);
}

#----------------------------------------------------------------------

my $ossl_bin;
sub openssl_bin {
    return $ossl_bin ||= File::Which::which('openssl');
}

1;
