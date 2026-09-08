# frozen_string_literal: true

require "enum_site_setting"

class DefaultTextSizeSetting < EnumSiteSetting
  DEFAULT_TEXT_SIZES = UserOption.text_sizes.keys.map(&:to_s)

  class << self
    def valid_value?(val)
      values.any? { |v| v[:value].to_s == val.to_s }
    end

    def values
      @values ||= DEFAULT_TEXT_SIZES
    end
  end
end
