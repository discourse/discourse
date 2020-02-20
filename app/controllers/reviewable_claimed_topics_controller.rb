# frozen_string_literal: true

class ReviewableClaimedTopicsController < ApplicationController
  requires_login

  def create
    topic = Topic.find_by(id: params[:reviewable_claimed_topic][:topic_id])
    guardian.ensure_can_claim_reviewable_topic!(topic)
    ReviewableClaimedTopic.create(user_id: current_user.id, topic_id: topic.id)
    topic.reviewables.find_each do |reviewable|
      reviewable.log_history(:claimed, current_user)
    end
    render json: success_json
  rescue ActiveRecord::RecordNotUnique
    # This is just in case the validation fails under concurrency
    render json: success_json
  end

  def destroy
    topic = Topic.find_by(id: params[:id])
    raise Discourse::NotFound if topic.blank?

    guardian.ensure_can_claim_reviewable_topic!(topic)
    ReviewableClaimedTopic.where(topic_id: topic.id).delete_all
    topic.reviewables.find_each do |reviewable|
      reviewable.log_history(:unclaimed, current_user)
    end

    render json: success_json
  end
end
