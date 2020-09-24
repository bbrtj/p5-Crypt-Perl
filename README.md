# NAME

Crypt::Perl - Cryptography in pure Perl

# DESCRIPTION

Just as it sounds: cryptography with no non-core XS dependencies!
This is useful if you don’t have access to
other tools that do this work like [OpenSSL](http://openssl.org), [CryptX](https://metacpan.org/pod/CryptX),
etc. Of course, if you do have access to one of those tools, they may suit
your purpose better.

See submodules for usage examples of:

- Key generation
- Key parsing
- Signing & verification
- Encryption & decryption
- Import ([Crypt::Perl::PK](https://metacpan.org/pod/Crypt::Perl::PK)) from & export to [JSON Web Key](https://tools.ietf.org/html/rfc7517) format
- [JWK thumbprints](https://tools.ietf.org/html/rfc7638)
- Certificate Signing Request (PKCS #10) generation ([Crypt::Perl::PKCS10](https://metacpan.org/pod/Crypt::Perl::PKCS10))
- SSL/TLS certificate (X.509) generation ([Crypt::Perl::X509v3](https://metacpan.org/pod/Crypt::Perl::X509v3)), including
a broad variety of extensions

# SUPPORTED PUBLIC KEY ALGORITHMS

- [RSA](https://metacpan.org/pod/Crypt::Perl::RSA)
- [ECDSA](https://metacpan.org/pod/Crypt::Perl::ECDSA)
- [Ed25519](https://metacpan.org/pod/Crypt::Perl::Ed25519)

# SECURITY

[Bytes::Random::Secure::Tiny](https://metacpan.org/pod/Bytes::Random::Secure::Tiny) supplies random number generation; see that
module’s documentation for details of its reliability. (Code paths that
don’t need randomness—such as deterministic ECDSA signatures—should be
even safer.)

An extensive test suite is included that compares against
[OpenSSL](https://openssl.org) and
[LibTomCrypt](https://www.libtom.net/LibTomCrypt/) (i.e., [CryptX](https://metacpan.org/pod/CryptX)),
when available.

That said: **NO GUARANTEES!!!** It’s best to restrict use of this library
to contexts where more “visible” cryptography libraries like the ones
mentioned elsewhere here are unavailable.

Of course, even [OpenSSL has not been trouble-free, either!](https://www.openssl.org/news/vulnerabilities.html)

Caveat emptor.

# HISTORICAL VULNERABILITIES

- [CVE-2020-13895](https://nvd.nist.gov/vuln/detail/CVE-2020-13895)
- [CVE-2020-17478](https://nvd.nist.gov/vuln/detail/CVE-2020-17478)

# SPEED

RSA key generation is slow—too slow, probably, unless you have
[Math::BigInt::GMP](https://metacpan.org/pod/Math::BigInt::GMP) or [Math::BigInt::Pari](https://metacpan.org/pod/Math::BigInt::Pari) (either of which requires XS).
It’s one application where pure-Perl cryptography just doesn’t seem
feasible. :-( Everything else, though, including all ECDSA and Ed25519
operations, should be fine in pure Perl.

Note that this distribution’s test suite is also pretty slow without an
XS backend.

# TODO

There are TODO items listed in the submodules; the following are general
to the entire distribution.

- Document the exception system so that applications can use it.
- Add more tests, e.g., against [CryptX](https://metacpan.org/pod/CryptX).
- Some formal security audit would be nice.
- Make it faster :)

# ACKNOWLEDGEMENTS

Much of the logic here comes from Kenji Urushima’s [jsrsasign](https://github.com/kjur/jsrsasign).

Most of the tests depend on the near-ubiquitous [OpenSSL](http://openssl.org),
without which the Internet would be a very, very different reality from
what we know!

The Ed25519 logic is ported from [forge.js](https://github.com/digitalbazaar/forge/blob/master/lib/ed25519.js).

Deterministic ECDSA logic derived in part from [python-ecdsa](https://github.com/ecdsa/python-ecdsa).

Other parts are ported from [LibTomCrypt](http://www.libtom.net).

Special thanks to Antonio de la Piedra for having submitted
multiple high-quality, in-depth bug reports.

# LICENSE

This library is licensed under the same license as Perl.

# AUTHOR

Felipe Gasper (FELIPE)
