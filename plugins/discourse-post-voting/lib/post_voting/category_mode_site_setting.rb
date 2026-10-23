# frozen_string_literal: true

require "enum_site_setting"

module PostVoting
  class CategoryModeSiteSetting < ::EnumSiteSetting
    ALL_CATEGORIES = "all_categories"
    OPT_IN = "opt_in"
    OPT_OUT = "opt_out"

    def self.valid_value?(val)
      values.any? { |value| value[:value] == val }
    end

    def self.values
      @values ||= [
        { name: "post_voting.category_mode.all_categories", value: ALL_CATEGORIES },
        { name: "post_voting.category_mode.opt_in", value: OPT_IN },
        { name: "post_voting.category_mode.opt_out", value: OPT_OUT },
      ]
    end

    def self.translate_names?
      true
    end

    # `nil` for a category that has no value yet, so callers can fall back to
    # the mode's default.
    def self.normalize_override(value)
      case value
      when "true", "t", "1", true
        true
      when "false", "f", "0", false
        false
      end
    end
  end
end
