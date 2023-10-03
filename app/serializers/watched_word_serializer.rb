# frozen_string_literal: true

class WatchedWordSerializer < ApplicationSerializer
  attributes :id, :word, :regexp, :replacement, :action, :case_sensitive

  def regexp
    WordWatcher.word_to_regexp(word, engine: :js)
  end

  def action
    WatchedWord.actions[object.action]
  end

  def include_replacement?
    WatchedWord.has_replacement?(action)
  end
end
