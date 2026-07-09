# frozen_string_literal: true

require "enum_site_setting"

class CategoryScopeSiteSetting < EnumSiteSetting
  def self.valid_value?(val)
    values.any? { |value| value[:value] == val }
  end

  def self.values
    @values ||= [
      { name: "category_scope.all", value: "all" },
      { name: "category_scope.public", value: "public" },
      { name: "category_scope.include", value: "include" },
      { name: "category_scope.include_strict", value: "include_strict" },
      { name: "category_scope.exclude", value: "exclude" },
      { name: "category_scope.exclude_strict", value: "exclude_strict" },
    ]
  end

  def self.translate_names?
    true
  end
end
