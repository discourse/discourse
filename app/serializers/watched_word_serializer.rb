# frozen_string_literal: true

class WatchedWordSerializer < ApplicationSerializer
  attributes :id, :word, :replacement, :action, :first_post_only

  def action
    WatchedWord.actions[object.action]
  end

  def include_replacement?
    WatchedWord.has_replacement?(object.action)
  end

  def include_first_post_only?
    WatchedWord.can_apply_to_first_post_only?(object.action)
  end
end
