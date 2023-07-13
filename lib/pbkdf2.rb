# frozen_string_literal: true

class Pbkdf2
  def self.hash_password(password, salt, iterations, algorithm = "sha256", length: 32)
    OpenSSL::KDF.pbkdf2_hmac(
      password,
      salt: salt,
      iterations: iterations,
      length: length,
      hash: algorithm,
    ).unpack1("H*")
  end
end
