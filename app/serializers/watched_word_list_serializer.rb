# frozen_string_literal: true

class WatchedWordListSerializer < ApplicationSerializer
  attributes :actions, :words, :compiled_regular_expressions

  def actions
    if SiteSetting.tagging_enabled
      WatchedWord.actions.keys
    else
      WatchedWord.actions.keys.filter { |k| k != :tag }
    end
  end

  def words
    object.map { |word| WatchedWordSerializer.new(word, root: false) }
  end

  def compiled_regular_expressions
    expressions = {}
    actions.each do |action|
      expressions[action] = WordWatcher.serializable_word_matcher_regexp(action, engine: :js)
    end
    expressions
  end
end
