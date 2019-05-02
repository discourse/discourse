# frozen_string_literal: true

class RegexSettingValidator

  LOREM = 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nullam eget sem non elit tincidunt rhoncus.'.freeze

  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(val)
    !val.present? || valid_regex?(val)
  end

  # Check that string is a valid regex, and that it doesn't match most of the lorem string.
  def valid_regex?(val)
    r = Regexp.new(val)
    matches = r.match(LOREM)
    matches.nil? || matches[0].length < (LOREM.length - 10)
  rescue
    false
  end

  def error_message
    I18n.t('site_settings.errors.invalid_regex')
  end
end
