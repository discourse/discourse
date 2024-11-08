# frozen_string_literal: true

class PasswordHasher
  class InvalidAlgorithmError < StandardError
  end

  class UnsupportedAlgorithmError < StandardError
  end

  @@handlers = {}

  def self.register_handler(id, &blk)
    @@handlers[id] = blk
  end

  # Algorithm should be specified according to the id/params parts of the
  # PHC string format.
  # https://github.com/P-H-C/phc-string-format/blob/master/phc-sf-spec.md
  def self.hash_password(password:, salt:, algorithm:)
    algorithm = algorithm.delete_prefix("$").delete_suffix("$")

    parts = algorithm.split("$")
    raise InvalidAlgorithmError if parts.length != 2

    algorithm_id, algorithm_params = parts

    algorithm_params = algorithm_params.split(",").map { |pair| pair.split("=") }.to_h

    handler = @@handlers[algorithm_id]
    if handler.nil?
      raise UnsupportedAlgorithmError.new "#{algorithm_id} is not a supported password algorithm"
    end

    handler.call(password: password, salt: salt, params: algorithm_params)
  end

  register_handler("pbkdf2-sha256") do |password:, salt:, params:|
    raise ArgumentError.new("Salt and password must be supplied") if password.blank? || salt.blank?

    if params["l"].to_i != 32
      raise UnsupportedAlgorithmError.new("pbkdf2 implementation only supports l=32")
    end

    if params["i"].to_i < 1
      raise UnsupportedAlgorithmError.new("pbkdf2 iterations must be 1 or more")
    end

    Pbkdf2.hash_password(password, salt, params["i"].to_i, "sha256")
  end
end
