# frozen_string_literal: true

class WatchedWordListSerializer < ApplicationSerializer
  attributes :actions, :words, :compiled_regular_expressions

  def actions
    SiteSetting.tagging_enabled ? WatchedWord.actions.keys
                                : WatchedWord.actions.keys.filter { |k| k != :tag }
  end

  def words
    object.map do |word|
      WatchedWordSerializer.new(word, root: false)
    end
  end

  def compiled_regular_expressions
    expressions = {}
    actions.each do |action|
      expressions[action] = WordWatcher.word_matcher_regexp(action)&.source
    end
    expressions
  end
end
