#
# Clean up a text
#
class TextCleaner

  def self.title_options
    # cf. http://meta.discourse.org/t/should-we-have-auto-replace-rules-in-titles/5687
    {
      deduplicate_exclamation_marks: SiteSetting.title_prettify,
      deduplicate_question_marks: SiteSetting.title_prettify,
      replace_all_upper_case: SiteSetting.title_prettify,
      capitalize_first_letter: SiteSetting.title_prettify,
      remove_all_periods_from_the_end: SiteSetting.title_prettify,
      remove_extraneous_space: SiteSetting.title_prettify && SiteSetting.default_locale == "en",
      fixes_interior_spaces: true,
      strip_whitespaces: true
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
    text.tr!('A-Z', 'a-z') if opts[:replace_all_upper_case] && (text =~ /[A-Z]+/) && (text == text.upcase)
    # Capitalize first letter, but only when entire first word is lowercase
    text.sub!(/\A([a-z]*)\b/) { |first| first.capitalize } if opts[:capitalize_first_letter]
    # Remove unnecessary periods at the end
    text.sub!(/([^.])\.+(\s*)\z/, '\1\2') if opts[:remove_all_periods_from_the_end]
    # Remove extraneous space before the end punctuation
    text.sub!(/\s+([!?]\s*)\z/, '\1') if opts[:remove_extraneous_space]
    # Fixes interior spaces
    text.gsub!(/ +/, ' ') if opts[:fixes_interior_spaces]
    # Strip whitespaces
    text.strip! if opts[:strip_whitespaces]

    text
  end

end
