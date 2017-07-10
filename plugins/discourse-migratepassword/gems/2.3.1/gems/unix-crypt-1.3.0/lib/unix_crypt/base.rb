class UnixCrypt::Base
  def self.build(password, salt = nil, rounds = nil)
    salt ||= generate_salt
    if salt.length > max_salt_length
      raise UnixCrypt::SaltTooLongError, "Salts longer than #{max_salt_length} characters are not permitted"
    end

    construct_password(password, salt, rounds)
  end

  def self.hash(password, salt, rounds = nil)
    bit_specified_base64encode internal_hash(prepare_password(password), salt, rounds)
  end

  def self.generate_salt
    # Generates a random salt using the same character set as the base64 encoding
    # used by the hash encoder.
    SecureRandom.base64((default_salt_length * 6 / 8.0).ceil).tr("+", ".")[0...default_salt_length]
  end

  protected
  def self.construct_password(password, salt, rounds)
    "$#{identifier}$#{rounds_marker rounds}#{salt}$#{hash(password, salt, rounds)}"
  end

  def self.bit_specified_base64encode(input)
    b64 = "./0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
    input = input.bytes.to_a
    output = ""
    byte_indexes.each do |i3, i2, i1|
      b1, b2, b3 = i1 && input[i1] || 0, i2 && input[i2] || 0, i3 && input[i3] || 0
      output <<
        b64[  b1 & 0b00111111]         <<
        b64[((b1 & 0b11000000) >> 6) |
            ((b2 & 0b00001111) << 2)]  <<
        b64[((b2 & 0b11110000) >> 4) |
            ((b3 & 0b00000011) << 4)]  <<
        b64[ (b3 & 0b11111100) >> 2]
    end

    remainder = 3 - (length % 3)
    remainder = 0 if remainder == 3
    output[0..-1-remainder]
  end

  def self.prepare_password(password)
    # For Ruby 1.9+, convert the password to UTF-8, then treat that new string
    # as binary for the digest methods.
    if password.respond_to?(:encode)
      password = password.encode("UTF-8")
      password.force_encoding("ASCII-8BIT")
    end

    password
  end

  def self.rounds_marker(rounds)
    nil
  end
end

