# frozen_string_literal: true

class WatchedWordListSerializer < ApplicationSerializer
  attributes :actions, :words, :regular_expressions, :compiled_regular_expressions

  def actions
    WatchedWord.actions.keys
  end

  def words
    object.map do |word|
      WatchedWordSerializer.new(word, root: false)
    end
  end

  # No point making this site setting `client: true` when it's only used
  # in the admin section
  def regular_expressions
    SiteSetting.watched_words_regular_expressions?
  end

  def compiled_regular_expressions
    expressions = {}
    WatchedWord.actions.keys.each do |action|
      expressions[action] = WordWatcher.word_matcher_regexp(action)&.source
    end
    expressions
  end
end
