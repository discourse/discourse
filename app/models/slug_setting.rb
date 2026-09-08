# frozen_string_literal: true

class SlugSetting < EnumSiteSetting
  VALUES = %w[ascii encoded none]

  class << self
    def valid_value?(val)
      VALUES.include?(val)
    end

    def values
      VALUES.map { |l| { name: l, value: l } }
    end
  end
end
