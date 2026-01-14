# frozen_string_literal: true

class PostVotingCommentSerializer < ApplicationSerializer
  attributes :id,
             :user_id,
             :name,
             :username,
             :created_at,
             :raw,
             :cooked,
             :post_voting_vote_count,
             :user_voted,
             :available_flags,
             :reviewable_id

  attr_accessor :comments_user_voted

  def name
    object.user&.name
  end

  def username
    object.user&.username
  end

  def user_voted
    if @comments_user_voted
      @comments_user_voted[object.id]
    else
      scope.present? && object.votes.exists?(user: scope.user)
    end
  end

  def reviewable_id
    return @reviewable_id if defined?(@reviewable_id)
    return @reviewable_id = nil unless @options && @options[:reviewable_ids]

    @reviewable_id = @options[:reviewable_ids][object.id]
  end

  def available_flags
    return [] if !scope.can_flag_post_voting_comment?(object)
    return [] if reviewable_id.present? && user_flag_status == ReviewableScore.statuses[:pending]

    PostActionType.flag_types.map { |sym, id| sym }
  end

  def post_voting_vote_count
    object.qa_vote_count
  end
end
