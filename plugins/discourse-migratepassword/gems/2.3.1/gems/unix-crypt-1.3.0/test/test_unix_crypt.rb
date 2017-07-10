# encoding: utf-8
#
# MD5 test cases constructed by Mark Johnston, taken from
# http://code.activestate.com/recipes/325204-passwd-file-compatible-1-md5-crypt/
#
# SHA test cases found in Ulrich Drepper's paper on SHA crypt, taken from
# http://www.akkadia.org/drepper/SHA-crypt.txt
#

require 'test/unit'
require File.expand_path('../../lib/unix_crypt', __FILE__)

class UnixCryptTest < Test::Unit::TestCase
  def test_password_validity
    tests = [
      # DES
      ["PQ", "test", "PQl1.p7BcJRuM"],
      ["xx", "much longer password here", "xxtHrOGVa3182"],

      # MD5
      [nil, ' ', '$1$yiiZbNIH$YiCsHZjcTkYd31wkgW8JF.'],
      [nil, 'pass', '$1$YeNsbWdH$wvOF8JdqsoiLix754LTW90'],
      [nil, '____fifteen____', '$1$s9lUWACI$Kk1jtIVVdmT01p0z3b/hw1'],
      [nil, '____sixteen_____', '$1$dL3xbVZI$kkgqhCanLdxODGq14g/tW1'],
      [nil, '____seventeen____', '$1$NaH5na7J$j7y8Iss0hcRbu3kzoJs5V.'],
      [nil, '__________thirty-three___________', '$1$HO7Q6vzJ$yGwp2wbL5D7eOVzOmxpsy.'],
      [nil, 'Pässword', '$1$NaH5na7J$MvnEHcxaKZzgBk8QdjdAQ0'],

      # SHA256
      ["$5$saltstring", "Hello world!", "$5$saltstring$5B8vYYiY.CVt1RlTTf8KbXBH3hsxY/GNooZaBBGWEc5"],
      ["$5$rounds=10000$saltstringsaltstring", "Hello world!", "$5$rounds=10000$saltstringsaltst$3xv.VbSHBb41AL9AvLeujZkZRBAwqFMz2.opqey6IcA"],
      ["$5$rounds=5000$toolongsaltstring", "This is just a test", "$5$rounds=5000$toolongsaltstrin$Un/5jzAHMgOGZ5.mWJpuVolil07guHPvOW8mGRcvxa5"],
      ["$5$rounds=1400$anotherlongsaltstring", "a very much longer text to encrypt.  This one even stretches over morethan one line.", "$5$rounds=1400$anotherlongsalts$Rx.j8H.h8HjEDGomFU8bDkXm3XIUnzyxf12oP84Bnq1"],
      ["$5$rounds=77777$short", "we have a short salt string but not a short password", "$5$rounds=77777$short$JiO1O3ZpDAxGJeaDIuqCoEFysAe1mZNJRs3pw0KQRd/"],
      ["$5$rounds=123456$asaltof16chars..", "a short string", "$5$rounds=123456$asaltof16chars..$gP3VQ/6X7UUEW3HkBn2w1/Ptq2jxPyzV/cZKmF/wJvD"],
      ["$5$rounds=10$roundstoolow", "the minimum number is still observed", "$5$rounds=1000$roundstoolow$yfvwcWrQ8l/K0DAWyuPMDNHpIVlTQebY9l/gL972bIC"],

      # SHA512
      ["$6$saltstring", "Hello world!", "$6$saltstring$svn8UoSVapNtMuq1ukKS4tPQd8iKwSMHWjl/O817G3uBnIFNjnQJuesI68u4OTLiBFdcbYEdFCoEOfaS35inz1"],
      ["$6$rounds=10000$saltstringsaltstring", "Hello world!", "$6$rounds=10000$saltstringsaltst$OW1/O6BYHV6BcXZu8QVeXbDWra3Oeqh0sbHbbMCVNSnCM/UrjmM0Dp8vOuZeHBy/YTBmSK6H9qs/y3RnOaw5v."],
      ["$6$rounds=5000$toolongsaltstring", "This is just a test", "$6$rounds=5000$toolongsaltstrin$lQ8jolhgVRVhY4b5pZKaysCLi0QBxGoNeKQzQ3glMhwllF7oGDZxUhx1yxdYcz/e1JSbq3y6JMxxl8audkUEm0"],
      ["$6$rounds=1400$anotherlongsaltstring", "a very much longer text to encrypt.  This one even stretches over morethan one line.", "$6$rounds=1400$anotherlongsalts$POfYwTEok97VWcjxIiSOjiykti.o/pQs.wPvMxQ6Fm7I6IoYN3CmLs66x9t0oSwbtEW7o7UmJEiDwGqd8p4ur1"],
      ["$6$rounds=77777$short", "we have a short salt string but not a short password", "$6$rounds=77777$short$WuQyW2YR.hBNpjjRhpYD/ifIw05xdfeEyQoMxIXbkvr0gge1a1x3yRULJ5CCaUeOxFmtlcGZelFl5CxtgfiAc0"],
      ["$6$rounds=123456$asaltof16chars..", "a short string", "$6$rounds=123456$asaltof16chars..$BtCwjqMJGx5hrJhZywWvt0RLE8uZ4oPwcelCjmw2kSYu.Ec6ycULevoBK25fs2xXgMNrCzIMVcgEJAstJeonj1"],
      ["$6$rounds=10$roundstoolow", "the minimum number is still observed", "$6$rounds=1000$roundstoolow$kUMsbe306n21p9R.FRkW3IGn.S9NPN0x50YhH1xhLsPuWGsUSklZt58jaTfF4ZEQpyUNGc0dqbpBYYBaHHrsX."]
    ]

    tests.each_with_index do |(salt, password, expected), index|
      assert UnixCrypt.valid?(password, expected), "Password '#{password}' (index #{index}) failed"
    end
  end

  def test_validity_of_des_password_generation
    hash = UnixCrypt::DES.build("test")
    assert UnixCrypt.valid?("test", hash)

    hash = UnixCrypt::DES.build("test", 'xx')
    assert UnixCrypt.valid?("test", hash)
  end

  def test_validity_of_md5_password_generation
    hash = UnixCrypt::MD5.build("test")
    assert UnixCrypt.valid?("test", hash)

    hash = UnixCrypt::MD5.build("test", "abcdefgh")
    assert UnixCrypt.valid?("test", hash)
  end

  def test_validity_of_sha256_password_generation
    hash = UnixCrypt::SHA256.build("test")
    assert UnixCrypt.valid?("test", hash)

    hash = UnixCrypt::SHA256.build("test", "1234567890123456")
    assert UnixCrypt.valid?("test", hash)
  end

  def test_validity_of_sha512_password_generation
    hash = UnixCrypt::SHA512.build("test")
    assert UnixCrypt.valid?("test", hash)

    hash = UnixCrypt::SHA512.build("test", "1234567890123456")
    assert UnixCrypt.valid?("test", hash)
  end

  def test_structure_of_generated_passwords_and_salts
    assert_match %r{\A[a-zA-Z0-9./]{13}\z}, UnixCrypt::DES.build("test password")
    assert_match %r{\Azz[a-zA-Z0-9./]{11}\z}, UnixCrypt::DES.build("test password", 'zz')

    assert_match %r{\A\$1\$[a-zA-Z0-9./]{8}\$[a-zA-Z0-9./]{22}\z}, UnixCrypt::MD5.build("test password")
    assert_match %r{\A\$1\$abcdefgh\$[a-zA-Z0-9./]{22}\z}, UnixCrypt::MD5.build("test password", "abcdefgh")

    assert_match %r{\A\$5\$[a-zA-Z0-9./]{16}\$[a-zA-Z0-9./]{43}\z}, UnixCrypt::SHA256.build("test password")
    assert_match %r{\A\$5\$0123456789abcdef\$[a-zA-Z0-9./]{43}\z}, UnixCrypt::SHA256.build("test password", "0123456789abcdef")

    assert_match %r{\A\$6\$[a-zA-Z0-9./]{16}\$[a-zA-Z0-9./]{86}\z}, UnixCrypt::SHA512.build("test password")
    assert_match %r{\A\$6\$0123456789abcdef\$[a-zA-Z0-9./]{86}\z}, UnixCrypt::SHA512.build("test password", "0123456789abcdef")
  end

  def test_password_generation_with_rounds
    hash = UnixCrypt::SHA512.build("test password", nil, 5678)
    assert_match %r{\A\$6\$rounds=5678\$[a-zA-Z0-9./]{16}\$[a-zA-Z0-9./]{86}\z}, hash
    assert UnixCrypt.valid?("test password", hash)

    assert_match %r{\A\$6\$rounds=5678\$salted\$[a-zA-Z0-9./]{86}\z}, UnixCrypt::SHA512.build("test password", "salted", 5678)
  end

  def test_default_rounds_does_not_add_rounds_marker
    assert_match %r{\A\$6\$salted\$[a-zA-Z0-9./]{86}\z}, UnixCrypt::SHA512.build("test password", "salted", 5000) # the default number of rounds
  end

  def test_rounds_bounds
    hash = UnixCrypt::SHA512.build("test password", nil, 567)
    assert_match %r{\A\$6\$rounds=1000\$[a-zA-Z0-9./]{16}\$[a-zA-Z0-9./]{86}\z}, hash
    assert UnixCrypt.valid?("test password", hash)
  end

  def test_salt_is_not_longer_than_max_length
    assert_raise(UnixCrypt::SaltTooLongError) { UnixCrypt::DES.build("test", "123") }
    assert_raise(UnixCrypt::SaltTooLongError) { UnixCrypt::MD5.build("test", "123456789") }
    assert_raise(UnixCrypt::SaltTooLongError) { UnixCrypt::SHA256.build("test", "12345678901234567") }
  end
end
