# frozen_string_literal: true

# Builds random human-friendly usernames (e.g. "QuietFalcon42") for accounts
# created without user input, where no signup data can (or may) be used to
# derive one. The word lists are site settings so communities can tailor them
# to their tone or language.
module RandomUsernameGenerator
  # Returns nil when the site has opted out, or when the configured word lists
  # can't produce a usable name, so callers fall back to their own suggestion.
  class << self
    def generate
      return nil if !SiteSetting.enable_random_usernames

      adjective = pick(SiteSetting.random_username_adjectives_map)
      noun = pick(SiteSetting.random_username_nouns_map)
      return nil if adjective.blank? || noun.blank?

      # A numeric suffix widens the namespace well beyond the word-pair count,
      # so very large sites don't exhaust it.
      candidate = "#{adjective}#{noun}#{rand(10..99)}"
      UserNameSuggester.find_available_username_based_on(
        UserNameSuggester.rightsize_username(candidate),
      )
    end

    # Words are admin-supplied, so skip any that sanitization would rewrite (a
    # non-Latin word once unicode usernames are turned back off, say) rather than
    # letting the replacement character leak into generated names.
    def pick(words)
      word = words.shuffle.find { |w| UserNameSuggester.sanitize_username(w) == w }
      # Only the leading letter, so a word like "McFly" keeps its shape.
      word&.sub(/\A./) { |first| first.upcase }
    end
  end

  private_class_method :pick
end
