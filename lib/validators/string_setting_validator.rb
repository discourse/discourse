class StringSettingValidator
  def initialize(opts={})
    @opts = opts
    @regex = Regexp.new(opts[:regex]) if opts[:regex]
    @regex_error = opts[:regex_error] || 'site_settings.errors.regex_mismatch'
  end

  def valid_value?(val)
    return true if !val.present?

    if (@opts[:min] and @opts[:min].to_i > val.length) || (@opts[:max] and @opts[:max].to_i < val.length)
      @length_fail = true
      return false
    end

    if @regex and !(val =~ @regex)
      @regex_fail = true
      return false
    end

    true
  end

  def error_message
    if @regex_fail
      I18n.t(@regex_error)
    elsif @length_fail
      if @opts[:min] && @opts[:max]
        I18n.t('site_settings.errors.invalid_string_min_max', {min: @opts[:min], max: @opts[:max]})
      elsif @opts[:min]
        I18n.t('site_settings.errors.invalid_string_min', {min: @opts[:min]})
      else
        I18n.t('site_settings.errors.invalid_string_max', {max: @opts[:max]})
      end
    else
      I18n.t('site_settings.errors.invalid_string')
    end
  end
end
