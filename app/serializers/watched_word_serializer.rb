# frozen_string_literal: true

class WatchedWordSerializer < ApplicationSerializer
  attributes :id, :word, :replacement, :action, :first_post_only

  def action
    WatchedWord.actions[object.action]
  end

  def include_replacement?
    WatchedWord.has_replacement?(object.action)
  end
end
