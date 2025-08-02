# frozen_string_literal: true

# onebox_locale is just like any other locale setting, except it allows for an empty value,
# which is used to indicate that the default_locale should be used for onebox_locale.
class OneboxLocaleSiteSetting < LocaleSiteSetting
  def self.valid_value?(val)
    supported_locales.include?(val) || val == ""
  end

  @lock = Mutex.new
end
