# frozen_string_literal: true

class CensoredWordsValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    words_regexps = WordWatcher.word_matcher_regexp_list(:censor)
    if WordWatcher.words_for_action_exists?(:censor).present? && words_regexps.present?
      censored_words = censor_words(value, words_regexps)
      return if censored_words.blank?

      record.errors.add(
        attribute,
        :contains_censored_words,
        censored_words: join_censored_words(censored_words),
      )
    end
  end

  private

  def censor_words(value, regexps)
    censored_words = regexps.map { |r| value.scan(r) }
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
    censored_words.join(", ")
  end
end
