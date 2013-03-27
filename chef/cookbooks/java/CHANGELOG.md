## v1.10.0:

* [COOK-2400] - Allow java ark :url to be https
* [COOK-2436] - Upgrade needed for oracle jdk in java cookbook

## v1.9.6:

* [COOK-2412] - add support for Oracle Linux

## v1.9.4:

* [COOK-2083] - Run set-env-java-home in Java cookbook only if necessary
* [COOK-2332] - ark provider does not allow for *.tgz tarballs to be used
* [COOK-2345] - Java cookbook fails on CentOS6 (update-java-alternatives)

## v1.9.2:

* [COOK-2306] - FoodCritic fixes for java cookbook

## v1.9.0:

* [COOK-2236] - Update the Oracle Java version in the Java cookbook to
  release 1.7u11

## v1.8.2:

* [COOK-2205] - Fix for missing /usr/lib/jvm/default-java on Debian

## v1.8.0:

* [COOK-2095] - Add windows support

## v1.7.0:

* [COOK-2001] - improvements for Oracle update-alternatives
  - When installing an Oracle JDK it is now registered with a higher
    priority than OpenJDK. (Related to COOK-1131.)
  - When running both the oracle and oracle_i386 recipes, alternatives
    are now created for both JDKs.
  - Alternatives are now created for all binaries listed in version
    specific attributes. (Related to COOK-1563 and COOK-1635.)
  - When installing Oracke JDKs on Ubuntu, create .jinfo files for use
    with update-java-alternatives. Commands to set/install
    alternatives now only run if needed.

## v1.6.4:

* [COOK-1930] - fixed typo in attribute for java 5 on i586

## v1.6.2:

* whyrun support in `java_ark` LWRP
* CHEF-1804 compatibility
* [COOK-1786]- install Java 6u37 and Java 7u9
* [COOK-1819] -incorrect warning text about
  `node['java']['oracle']['accept_oracle_download_terms']`

## v1.6.0:

* [COOK-1218] - Install Oracle JDK from Oracle download directly
* [COOK-1631] - set JAVA_HOME in openjdk recipe
* [COOK-1655] - Install correct architecture on Amazon Linux

## v1.5.4:

* [COOK-885] - update alternatives called on wrong file
* [COOK-1607] - use shellout instead of execute resource to update
  alternatives

## v1.5.2:

* [COOK-1200] - remove sun-java6-jre on Ubuntu before installing
  Oracle's Java
* [COOK-1260] - fails on Ubuntu 12.04 64bit with openjdk7
* [COOK-1265] - Oracle Java should symlink the jar command

## v1.5.0:

* [COOK-1146] - Oracle now prevents download of JDK via non-browser
* [COOK-1114] - fix File.exists?

## v1.4.2:

* [COOK-1051] - fix attributes typo and platform case switch
  consistency

## v1.4.0:

* [COOK-858] - numerous updates: handle jdk6 and 7, switch from sun to
  oracle, make openjdk default, add `java_ark` LWRP.
* [COOK-942] - FreeBSD support
* [COOK-520] - ArchLinux support
