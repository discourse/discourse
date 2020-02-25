# frozen_string_literal: true

class SlugSetting < EnumSiteSetting

  VALUES = %w(ascii encoded none)

  def self.valid_value?(val)
    VALUES.include?(val)
  end

  def self.values
    VALUES.map do |l|
      { name: l, value: l }
    end
  end

end
