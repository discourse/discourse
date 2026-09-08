# frozen_string_literal: true

class EmailLevelSiteSetting < EnumSiteSetting
  class << self
    def valid_value?(val)
      val.to_i.to_s == val.to_s && values.any? { |v| v[:value] == val.to_i }
    end

    def values
      @values ||= [
        { name: "user.email_level.always", value: 0 },
        { name: "user.email_level.only_when_away", value: 1 },
        { name: "user.email_level.never", value: 2 },
      ]
    end

    def translate_names?
      true
    end
  end
end
