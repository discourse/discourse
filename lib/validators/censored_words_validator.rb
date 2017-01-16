class CensoredWordsValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    if !SiteSetting.censored_words.blank? && value =~ /#{escape_censored_words}/i
      record.errors.add(
        attribute, :contains_censored_words,
        censored_words: SiteSetting.censored_words
      )
    elsif !SiteSetting.censored_pattern.blank? && value =~ /#{SiteSetting.censored_pattern}/i
      record.errors.add(
        attribute, :matches_censored_pattern,
        censored_pattern: SiteSetting.censored_pattern
      )
    end
  end

  private

  def escape_censored_words
    # TODO escape with single slashes
    SiteSetting.censored_words
                              .gsub('*', '\*')
                              .gsub(')', '\)')
                              .gsub('(', '\(')
                              .gsub('[', '\[')
                              .gsub(']', '\]')
  end
end
