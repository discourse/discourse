# frozen_string_literal: true

class WatchedWordsValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    if matches = WordWatcher.new(value).should_block?.presence
      if matches.size == 1
        key = 'contains_blocked_word'
        translation_args = { word: matches[0] }
      else
        key = 'contains_blocked_words'
        translation_args = { words: matches.join(', ') }
      end
      record.errors.add(:base, I18n.t(key, translation_args))
    end
  end
end
