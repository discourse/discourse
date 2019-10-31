# frozen_string_literal: true

class WatchedWordSerializer < ApplicationSerializer
  root 'watched_word'

  attributes :id, :word, :action

  def action
    WatchedWord.actions[object.action]
  end
end
