class IntegerSettingValidator
  def initialize(opts={})
    @opts = opts
  end

  def valid_value?(val)
    return false if val.to_i.to_s != val.to_s
    return false if @opts[:min] and @opts[:min].to_i > val.to_i
    return false if @opts[:max] and @opts[:max].to_i < val.to_i
    true
  end

  def error_message
    if @opts[:min] && @opts[:max]
      I18n.t('site_settings.errors.invalid_integer_min_max', {min: @opts[:min], max: @opts[:max]})
    elsif @opts[:min]
      I18n.t('site_settings.errors.invalid_integer_min', {min: @opts[:min]})
    elsif @opts[:max]
      I18n.t('site_settings.errors.invalid_integer_max', {max: @opts[:max]})
    else
      I18n.t('site_settings.errors.invalid_integer')
    end
  end
end
