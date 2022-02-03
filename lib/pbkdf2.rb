# frozen_string_literal: true

# Note: This logic was originally extracted from the Pbkdf2 gem to fix Ruby 2.0
# issues, but that gem has gone stale so we won't be returning to it.

require 'openssl'
require 'xorcist'

class Pbkdf2
  def self.hash_password(password, salt, iterations, algorithm = "sha256")

    h = OpenSSL::Digest.new(algorithm)

    u = ret = prf(h, password, salt + [1].pack("N"))

    2.upto(iterations) do
      u = prf(h, password, u)
      Xorcist.xor!(ret, u)
    end

    ret.bytes.map { |b| ("0" + b.to_s(16))[-2..-1] }.join("")
  end

  protected

  def self.prf(hash_function, password, data)
    OpenSSL::HMAC.digest(hash_function, password, data)
  end

end
