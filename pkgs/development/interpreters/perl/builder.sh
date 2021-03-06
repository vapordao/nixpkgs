buildinputs="$patch"
. $stdenv/setup

tar xvfz $src
cd perl-*

# Perl's Configure messes with PATH.  We can't have that, so we patch it.
# Yeah, this is an ugly hack.
if test "$NIX_ENFORCE_PURITY" = "1" -a -n "$NIX_STORE"; then
    cat Configure | \
        grep -v '^paths=' | \
        grep -v '^locincpth=' | \
        grep -v '^xlibpth=' | \
        grep -v '^glibpth=' | \
        grep -v '^loclibpth=' | \
        grep -v '^locincpth=' | \
        cat > Configure.tmp
    mv Configure.tmp Configure
    chmod +x Configure
fi

patch -p1 < $srcPatch

if test "$NIX_ENFORCE_PURITY" = "1" -a -n "$NIX_STORE"; then
    GLIBC=$(cat $NIX_GCC/nix-support/orig-glibc)
    extraflags="-Dlocincpth=$GLIBC/include -Dloclibpth=$GLIBC/lib"
fi

./Configure -de -Dcc=gcc -Dprefix=$out -Uinstallusrbinperl $extraflags
make
make install
