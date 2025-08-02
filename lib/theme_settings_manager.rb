# frozen_string_literal: true

class ThemeSettingsManager
  attr_reader :name, :theme, :default

  def self.types
    ThemeSetting.types
  end

  def self.cast_row_value(row)
    type_name = self.types.invert[row.data_type].downcase.capitalize
    klass = "ThemeSettingsManager::#{type_name}".constantize
    klass.cast(klass.extract_value_from_row(row))
  end

  def self.create(name, default, type, theme, opts = {})
    type_name = self.types.invert[type].downcase.capitalize
    klass = "ThemeSettingsManager::#{type_name}".constantize
    klass.new(name, default, theme, opts)
  end

  def self.cast(value)
    value
  end

  def self.extract_value_from_row(row)
    row.value
  end

  def initialize(name, default, theme, opts = {})
    @name = name.to_sym
    @default = default
    @theme = theme
    @opts = opts
    @types = self.class.types
  end

  def value
    has_record? ? db_record.value : default
  end

  def type_name
    self.class.name.demodulize.downcase.to_sym
  end

  def type
    @types[type_name]
  end

  def description
    @opts[:description] # Old method of specifying description. Is now overridden by locale file
  end

  def requests_refresh?
    @opts[:refresh]
  end

  def value=(new_value)
    ensure_is_valid_value!(new_value)
    value = new_value.to_s

    record = has_record? ? update_record!(value:) : create_record!(value:)

    record.value
  end

  def db_record
    # theme.theme_settings will already be preloaded, so it is better to use
    # `find` on an array, rather than make a round trip to the database
    theme.theme_settings.to_a.find do |i|
      i.name.to_s == @name.to_s && i.data_type.to_s == type.to_s
    end
  end

  def update_record!(args)
    db_record.tap { |instance| instance.update!(args) }
  end

  def create_record!(args)
    record = ThemeSetting.new(name: @name, data_type: type, theme: @theme, **args)
    record.save!
    record
  end

  def has_record?
    db_record.present?
  end

  def ensure_is_valid_value!(new_value)
    return if new_value.nil?

    error_messages = ThemeSettingsValidator.validate_value(new_value, type, @opts)
    raise Discourse::InvalidParameters.new error_messages.join(" ") if error_messages.present?
  end

  def has_min?
    min = @opts[:min]
    (min.is_a?(::Integer) || min.is_a?(::Float)) && min != -::Float::INFINITY
  end

  def has_max?
    max = @opts[:max]
    (max.is_a?(::Integer) || max.is_a?(::Float)) && max != ::Float::INFINITY
  end
end
