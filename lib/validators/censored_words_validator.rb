# frozen_string_literal: true

class CensoredWordsValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    if WordWatcher.words_for_action(:censor).present? && (censored_words = censor_words(value, censored_words_regexp)).present?
      record.errors.add(
        attribute, :contains_censored_words,
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
