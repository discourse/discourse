class PollOptionSerializer < ApplicationSerializer

  attributes :id, :html, :votes

  def id
    object.digest
  end

  def votes
    # `size` instead of `count` to prevent N+1
    object.poll_votes.size + object.anonymous_votes.to_i
  end

end
