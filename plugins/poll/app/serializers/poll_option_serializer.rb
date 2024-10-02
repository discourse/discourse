# frozen_string_literal: true

class PollOptionSerializer < ApplicationSerializer
  attributes :id, :html, :votes

  def id
    object.digest
  end

  def votes
    object.voters_count + object.anonymous_votes.to_i
  end

  def include_votes?
    scope[:can_see_results]
  end
end
