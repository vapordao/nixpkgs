{stdenv, fetchurl, gettext}:

assert gettext != null;

stdenv.mkDerivation {
  name = "popt-1.7";
  builder = ./builder.sh;
  src = fetchurl {
    url = ftp://ftp.rpm.org/pub/rpm/dist/rpm-4.1.x/popt-1.7.tar.gz;
    md5 = "5988e7aeb0ae4dac8d83561265984cc9";
  };
  gettext = gettext;
}
