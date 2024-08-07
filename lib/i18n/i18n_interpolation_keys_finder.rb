# frozen_string_literal: true

class I18nInterpolationKeysFinder
  def self.find(text)
    return [] unless text.is_a?(String)
    pattern = Regexp.union([*I18n.config.interpolation_patterns, /\{\{(\w+)\}\}/])
    keys = text.scan(pattern)
    keys.flatten!
    keys.compact!
    keys.uniq!
    keys
  end
end
