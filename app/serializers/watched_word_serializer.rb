# frozen_string_literal: true

class WatchedWordSerializer < ApplicationSerializer
  attributes :id, :word, :regexp, :replacement, :action

  def regexp
    WordWatcher.word_to_regexp(word)
  end

  def action
    WatchedWord.actions[object.action]
  end

  def include_replacement?
    WatchedWord.has_replacement?(action)
  end
end
