class I18nInterpolationKeysFinder
  def self.find(text)
    keys = text.scan(I18n::INTERPOLATION_PATTERN)
    keys.flatten!
    keys.compact!
    keys.uniq!
    keys
  end
end
