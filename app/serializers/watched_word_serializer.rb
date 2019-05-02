# frozen_string_literal: true

class WatchedWordSerializer < ApplicationSerializer
  attributes :id, :word, :action

  def action
    WatchedWord.actions[object.action]
  end
end
