# frozen_string_literal: true

class ReviewablePrioritySetting < EnumSiteSetting
  class << self
    def valid_value?(val)
      values.any? { |v| v[:value].to_s == val.to_s }
    end

    def values
      Reviewable.priorities.map do |p|
        { name: I18n.t("reviewables.priorities.#{p[0]}"), value: p[0] }
      end
    end

    def translate_names?
      false
    end
  end
end
