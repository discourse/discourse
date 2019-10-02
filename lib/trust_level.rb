# frozen_string_literal: true

class InvalidTrustLevel < StandardError; end

class TrustLevel

  attr_reader :id, :name

  class << self

    def [](level)
      raise InvalidTrustLevel if !valid?(level)
      level
    end

    def levels
      @levels ||= Enum.new(:newuser, :basic, :member, :regular, :leader, start: 0)
    end

    def all
      levels.map do |name_key, id|
        TrustLevel.new(name_key, id)
      end
    end

    def valid?(level)
      valid_range === level
    end

    def valid_range
      (0..4)
    end

    def compare(current_level, level)
      (current_level || 0) >= level
    end

  end

  def initialize(name_key, id)
    @name = I18n.t("trust_levels.#{name_key}.title")
    @id = id
  end

  def serializable_hash
    { id: @id, name: @name }
  end

end
