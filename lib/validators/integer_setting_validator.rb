# frozen_string_literal: true

class IntegerSettingValidator
  def initialize(opts = {})
    @opts = opts
    @opts[:min] = 0 unless @opts[:min].present? || @opts[:hidden]
    # set max closer to a long int
    @opts[:max] = 2_000_000_000 unless @opts[:max].present? || @opts[:hidden]
  end

  def valid_value?(val)
    return false if val.to_i.to_s != val.to_s
    return false if @opts[:min] && @opts[:min].to_i > (val.to_i)
    return false if @opts[:max] && @opts[:max].to_i < (val.to_i)
    true
  end

  def error_message
    if @opts[:min] && @opts[:max]
      I18n.t('site_settings.errors.invalid_integer_min_max', min: @opts[:min], max: @opts[:max])
    elsif @opts[:min]
      I18n.t('site_settings.errors.invalid_integer_min', min: @opts[:min])
    elsif @opts[:max]
      I18n.t('site_settings.errors.invalid_integer_max', max: @opts[:max])
    else
      I18n.t('site_settings.errors.invalid_integer')
    end
  end
end
