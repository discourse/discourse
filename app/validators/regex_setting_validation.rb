# frozen_string_literal: true

module RegexSettingValidation

  def initialize_regex_opts(opts = {})
    @regex = Regexp.new(opts[:regex]) if opts[:regex]
    @regex_error = opts[:regex_error] || 'site_settings.errors.regex_mismatch'
  end

  def regex_match?(val)
    if @regex && !(val =~ @regex)
      @regex_fail = true
      return false
    end

    true
  end

end
