#
# Clean up a text
#

# Whe use ActiveSupport mb_chars from here to properly support non ascii downcase
require 'active_support/core_ext/string/multibyte'

class TextCleaner

  def self.title_options
    # cf. http://meta.discourse.org/t/should-we-have-auto-replace-rules-in-titles/5687
    {
      deduplicate_exclamation_marks: SiteSetting.title_prettify,
      deduplicate_question_marks: SiteSetting.title_prettify,
      replace_all_upper_case: SiteSetting.title_prettify && !SiteSetting.allow_uppercase_posts,
      capitalize_first_letter: SiteSetting.title_prettify,
      remove_all_periods_from_the_end: SiteSetting.title_prettify,
      remove_extraneous_space: SiteSetting.title_prettify && SiteSetting.default_locale == "en",
      fixes_interior_spaces: true,
      strip_whitespaces: true,
      strip_zero_width_spaces: true
    }
  end

  def self.clean_title(title)
    TextCleaner.clean(title, TextCleaner.title_options)
  end

  def self.clean(text, opts = {})
    # Replace !!!!! with a single !
    text.gsub!(/!+/, '!') if opts[:deduplicate_exclamation_marks]
    # Replace ????? with a single ?
    text.gsub!(/\?+/, '?') if opts[:deduplicate_question_marks]
    # Replace all-caps text with regular case letters
    text = text.mb_chars.downcase.to_s if opts[:replace_all_upper_case] && (text == text.mb_chars.upcase)
    # Capitalize first letter, but only when entire first word is lowercase
    first, rest = text.split(' ', 2)
    if first && opts[:capitalize_first_letter] && first == first.mb_chars.downcase
      text = "#{first.mb_chars.capitalize}#{rest ? ' ' + rest : ''}"
    end
    # Remove unnecessary periods at the end
    text.sub!(/([^.])\.+(\s*)\z/, '\1\2') if opts[:remove_all_periods_from_the_end]
    # Remove extraneous space before the end punctuation
    text.sub!(/\s+([!?]\s*)\z/, '\1') if opts[:remove_extraneous_space]
    # Fixes interior spaces
    text.gsub!(/ +/, ' ') if opts[:fixes_interior_spaces]
    # Normalize whitespaces
    text = normalize_whitespaces(text)
    # Strip whitespaces
    text.strip! if opts[:strip_whitespaces]
    # Strip zero width spaces
    text.gsub!(/\u200b/, '') if opts[:strip_zero_width_spaces]

    text
  end

  @@whitespaces_regexp = Regexp.new("(\u00A0|\u1680|\u180E|[\u2000-\u200A]|\u2028|\u2029|\u202F|\u205F|\u3000)", "u").freeze

  def self.normalize_whitespaces(text)
    text&.gsub(@@whitespaces_regexp, ' ')
  end

end
