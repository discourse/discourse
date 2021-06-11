# frozen_string_literal: true

class InvalidTrustLevel < StandardError; end

class TrustLevel

  class << self

    def [](level)
      raise InvalidTrustLevel if !valid?(level)
      level
    end

    def levels
      @levels ||= Enum.new(:newuser, :basic, :member, :regular, :leader, start: 0)
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

    def name(level)
      I18n.t("js.trust_levels.names.#{levels[level]}")
    end
  end

end
