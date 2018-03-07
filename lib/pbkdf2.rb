# Note: the pbkdf2 gem is bust on 2.0, the logic is so simple I am not sure it makes sense to have this in a gem atm (Sam)
#
# Also PBKDF2 monkey patches string ... don't like that at all
#
# Happy to move back to PBKDF2 ruby gem provided:
#
# 1. It works on Ruby 2.0
# 2. It works on 1.9.3
# 3. It does not monkey patch string

require 'openssl'
require 'xor'

class Pbkdf2

  def self.hash_password(password, salt, iterations, algorithm = "sha256")

    h = OpenSSL::Digest.new(algorithm)

    u = ret = prf(h, password, salt + [1].pack("N"))

    2.upto(iterations) do
      u = prf(h, password, u)
     ret.xor!(u)
    end

    ret.bytes.map { |b| ("0" + b.to_s(16))[-2..-1] }.join("")
  end

  protected

  # fallback xor in case we need it for jruby ... way slower
  def self.xor(x, y)
    x.bytes.zip(y.bytes).map { |a, b| a ^ b }.pack('c*')
  end

  def self.prf(hash_function, password, data)
    OpenSSL::HMAC.digest(hash_function, password, data)
  end

end
