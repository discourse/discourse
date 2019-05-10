class ReviewableClaimedTopicsController < ApplicationController
  requires_login

  def create
    topic = Topic.find_by(id: params[:reviewable_claimed_topic][:topic_id])
    guardian.ensure_can_claim_reviewable_topic!(topic)
    ReviewableClaimedTopic.create!(user_id: current_user.id, topic_id: topic.id)
    render json: success_json
  end

  def destroy
    topic = Topic.find_by(id: params[:id])
    raise Discourse::NotFound if topic.blank?

    guardian.ensure_can_claim_reviewable_topic!(topic)
    ReviewableClaimedTopic.where(topic_id: topic.id).delete_all

    render json: success_json
  end
end
