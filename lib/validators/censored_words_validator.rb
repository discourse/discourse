# frozen_string_literal: true

class CensoredWordsValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    words_regexp = censored_words_regexp
    if WordWatcher.words_for_action(:censor).present? && !words_regexp.nil?
      censored_words = censor_words(value, words_regexp)
      return if censored_words.blank?
      record.errors.add(
        attribute,
        :contains_censored_words,
        censored_words: join_censored_words(censored_words)
      )
    end
  end

  private

  def censor_words(value, regexp)
    censored_words = value.scan(regexp)
    censored_words.flatten!
    censored_words.compact!
    censored_words.map!(&:strip)
    censored_words.select!(&:present?)
    censored_words.uniq!
    censored_words
  end

  def join_censored_words(censored_words)
    censored_words.map!(&:downcase)
    censored_words.uniq!
    censored_words.join(", ".freeze)
  end

  def censored_words_regexp
    WordWatcher.word_matcher_regexp :censor
  end
end
