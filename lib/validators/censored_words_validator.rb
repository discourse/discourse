class CensoredWordsValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    if !SiteSetting.censored_words.blank? && value =~ /#{SiteSetting.censored_words}/i
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
end
