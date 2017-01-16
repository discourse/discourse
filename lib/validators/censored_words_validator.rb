class CensoredWordsValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    if !SiteSetting.censored_words.blank? &&
      !(censored_words = value.scan(censored_words_regexp)).empty?

      record.errors.add(
        attribute, :contains_censored_words,
        censored_words: join_censored_words(censored_words)
      )
    elsif !SiteSetting.censored_pattern.blank? &&
      !(censored_words = value.scan(/#{SiteSetting.censored_pattern}/i)).empty?

      record.errors.add(
        attribute, :matches_censored_pattern,
        censored_words: join_censored_words(censored_words)
      )
    end
  end

  private

    def join_censored_words(censored_words)
      censored_words.map!(&:downcase)
      censored_words.uniq!
      censored_words.join(", ".freeze)
    end

    def censored_words_regexp
      Regexp.new(
        SiteSetting.censored_words.split('|'.freeze).map! { |w| Regexp.escape(w) }.join('|'.freeze),
        true
      )
    end
end
