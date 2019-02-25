class ThemeTranslationManager
  include ActiveModel::Serialization
  attr_reader :key, :default, :theme

  def self.list_from_hash(locale:, hash:, theme:, parent_keys: [])
    list = []
    hash.map do |key, value|
      this_key_array = parent_keys + [key]
      if value.is_a?(Hash)
        self.list_from_hash(locale: locale, hash: value, theme: theme, parent_keys: this_key_array)
      else
        self.new(locale: locale, theme: theme, key: this_key_array.join("."), default: value)
      end
    end.flatten
  end

  def initialize(locale:, key:, default:, theme:)
    @locale = locale
    @key = key
    @default = default
    @theme = theme
  end

  def value
    has_record? ? db_record.value : default
  end

  def value=(new_value)
    if new_value == @default
      db_record.destroy! if db_record
      new_value
    else
      if has_record?
        record = db_record
        record.value = new_value.to_s
        record.save!
      else
        record = create_record!(new_value.to_s)
      end
      record.value
    end
  end

  def db_record
    theme.theme_translation_overrides.to_a.find do |i|
      i.locale.to_s == @locale.to_s && i.translation_key.to_s == key.to_s
    end
  end

  def has_record?
    db_record.present?
  end

  def create_record!(value)
    record = ThemeTranslationOverride.create!(locale: @locale, translation_key: @key, theme: @theme, value: value)
  end
end
