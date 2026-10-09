# frozen_string_literal: true

class RandomUsernameWordListValidator
  def initialize(opts = {})
    @opts = opts
  end

  # An empty list would leave the generator with nothing to build from, and a
  # word that sanitizes away would silently shrink every generated username.
  def valid_value?(val)
    words = val.to_s.split("|")
    words.any? && words.all? { |word| UserNameSuggester.sanitize_username(word).presence == word }
  end

  def error_message
    I18n.t("site_settings.errors.invalid_random_username_word_list")
  end
end
