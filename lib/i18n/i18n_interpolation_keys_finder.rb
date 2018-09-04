class I18nInterpolationKeysFinder
  def self.find(text)
    keys = text.scan(Regexp.union(I18n::INTERPOLATION_PATTERN, /\{\{(\w+)\}\}/))
    keys.flatten!
    keys.compact!
    keys.uniq!
    keys
  end
end
