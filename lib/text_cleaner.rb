# frozen_string_literal: true

#
# Clean up a text
#

class TextCleaner
  ASCII_LOWERCASE_REGEXP = /[a-z]/
  ASCII_UPPERCASE_START_REGEXP = /\A[A-Z]/
  TRAILING_PERIODS_REGEXP = /([^.])\.+(\s*)\z/
  EXTRANEOUS_SPACE_REGEXP = /\s+([!?]\s*)\z/
  private_constant :ASCII_LOWERCASE_REGEXP,
                   :ASCII_UPPERCASE_START_REGEXP,
                   :TRAILING_PERIODS_REGEXP,
                   :EXTRANEOUS_SPACE_REGEXP

  def self.title_options
    # cf. http://meta.discourse.org/t/should-we-have-auto-replace-rules-in-titles/5687
    {
      deduplicate_exclamation_marks: SiteSetting.title_prettify,
      deduplicate_question_marks: SiteSetting.title_prettify,
      replace_all_upper_case: SiteSetting.title_prettify && !SiteSetting.allow_uppercase_posts,
      capitalize_first_letter: SiteSetting.title_prettify,
      remove_all_periods_from_the_end: SiteSetting.title_prettify,
      remove_extraneous_space:
        SiteSetting.title_prettify && SiteSetting.title_remove_extraneous_space,
      fixes_interior_spaces: true,
      strip_whitespaces: true,
      strip_zero_width_spaces: true,
      case_option: SiteSetting.default_locale == "tr_TR" ? :turkic : nil,
    }
  end

  def self.clean_title(title)
    TextCleaner.clean(title, TextCleaner.title_options)
  end

  def self.clean(text, opts = {})
    text = text.dup

    # Remove invalid byte sequences
    text.scrub!("")

    # Replace !!!!! with a single !
    text.squeeze!("!") if opts[:deduplicate_exclamation_marks] && text.include?("!!")

    # Replace ????? with a single ?
    text.squeeze!("?") if opts[:deduplicate_question_marks] && text.include?("??")

    # Replace all-caps text with regular case letters
    if opts[:replace_all_upper_case] && !ASCII_LOWERCASE_REGEXP.match?(text) &&
         (text == upcase(text, opts))
      text = downcase(text, opts)
    end

    # Capitalize first letter, but only when entire first word is lowercase
    if opts[:capitalize_first_letter] && !ASCII_UPPERCASE_START_REGEXP.match?(text)
      first, rest = text.split(" ", 2)
      if first && first == downcase(first, opts)
        text = +"#{capitalize(first, opts)}#{rest ? " " + rest : ""}"
      end
    end

    # Remove unnecessary periods at the end
    if opts[:remove_all_periods_from_the_end] && text.include?(".")
      text.sub!(TRAILING_PERIODS_REGEXP, '\1\2')
    end

    # Remove extraneous space before the end punctuation
    text.sub!(EXTRANEOUS_SPACE_REGEXP, '\1') if opts[:remove_extraneous_space]

    # Fixes interior spaces
    text.squeeze!(" ") if opts[:fixes_interior_spaces] && text.include?("  ")

    # Normalize whitespaces in place (text is already duplicated above)
    text.gsub!(@@whitespaces_regexp, " ")

    # Strip whitespaces
    text.strip! if opts[:strip_whitespaces]

    # Strip zero width spaces
    text.delete!("\u200b") if opts[:strip_zero_width_spaces] && text.include?("\u200b")

    text
  end

  @@whitespaces_regexp =
    Regexp.new(
      "(\u00A0|\u1680|\u180E|[\u2000-\u200A]|\u2028|\u2029|\u202F|\u205F|\u3000)",
      Regexp::IGNORECASE,
    ).freeze

  def self.normalize_whitespaces(text)
    text&.gsub(@@whitespaces_regexp, " ")
  end

  def self.downcase(text, opts)
    opts[:case_option] ? text.downcase(opts[:case_option]) : text.downcase
  end

  def self.upcase(text, opts)
    opts[:case_option] ? text.upcase(opts[:case_option]) : text.upcase
  end

  def self.capitalize(text, opts)
    opts[:case_option] ? text.capitalize(opts[:case_option]) : text.capitalize
  end
end
