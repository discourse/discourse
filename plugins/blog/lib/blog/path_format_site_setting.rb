# frozen_string_literal: true

require "enum_site_setting"

module ::Blog
  class PathFormatSiteSetting < ::EnumSiteSetting
    def self.valid_value?(value)
      values.any? { |entry| entry[:value] == value }
    end

    def self.values
      @values ||=
        %w[slug year_month_slug year_month_day_slug].map do |value|
          { name: "blog.admin.path_formats.#{value}", value: }
        end
    end

    def self.translate_names?
      true
    end
  end
end
