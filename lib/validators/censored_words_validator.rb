class CensoredWordsValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    if !SiteSetting.censored_words.blank? && value.match(escape_censored_words)
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
    Regexp.new(SiteSetting.censored_words.split('|').map { |w| Regexp.escape(w) }.join('|'), true)
  end
end
