# frozen_string_literal: true

class ReviewableClaimedTopicsController < ApplicationController
  requires_login

  def create
    topic = Topic.with_deleted.find_by(id: params[:reviewable_claimed_topic][:topic_id])
    automatic = params[:reviewable_claimed_topic][:automatic] == "true"
    guardian.ensure_can_claim_reviewable_topic!(topic, automatic)

    begin
      claim =
        ReviewableClaimedTopic.create!(user_id: current_user.id, topic_id: topic.id, automatic:)
    rescue ActiveRecord::RecordInvalid
      return render_json_error(I18n.t("reviewables.conflict"), status: 409)
    end

    claim.log_topic_history(:claimed, current_user)
    claim.publish_change(current_user, claimed: true)

    render json: success_json
  end

  def destroy
    topic = Topic.with_deleted.find_by(id: params[:id])
    automatic = params[:automatic] == "true"
    if topic.blank? || !guardian.can_claim_reviewable_topic?(topic, automatic)
      raise Discourse::NotFound
    end

    ReviewableClaimedTopic.find_by(topic_id: topic.id)&.release(current_user)

    render json: success_json
  end
end
