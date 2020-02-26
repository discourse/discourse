# frozen_string_literal: true

class ReviewableClaimedTopicsController < ApplicationController
  requires_login

  def create
    topic = Topic.with_deleted.find_by(id: params[:reviewable_claimed_topic][:topic_id])
    guardian.ensure_can_claim_reviewable_topic!(topic)

    begin
      ReviewableClaimedTopic.create!(user_id: current_user.id, topic_id: topic.id)
    rescue ActiveRecord::RecordInvalid
      return render_json_error(I18n.t('reviewables.conflict'), status: 409)
    end

    topic.reviewables.find_each do |reviewable|
      reviewable.log_history(:claimed, current_user)
    end

    notify_users(topic, current_user)
    render json: success_json
  end

  def destroy
    topic = Topic.with_deleted.find_by(id: params[:id])
    raise Discourse::NotFound if topic.blank?

    guardian.ensure_can_claim_reviewable_topic!(topic)
    ReviewableClaimedTopic.where(topic_id: topic.id).delete_all
    topic.reviewables.find_each do |reviewable|
      reviewable.log_history(:unclaimed, current_user)
    end

    notify_users(topic, nil)
    render json: success_json
  end

  private

  def notify_users(topic, claimed_by)
    user_ids = User.staff.pluck(:id)

    if SiteSetting.enable_category_group_review? && group_id = topic.category&.reviewable_by_group_id.presence
      user_ids.concat(GroupUser.where(group_id: group_id).pluck(:user_id))
      user_ids.uniq!
    end

    if claimed_by.present?
      data = { topic_id: topic.id, user: BasicUserSerializer.new(claimed_by, root: false).as_json }
    else
      data = { topic_id: topic.id }
    end

    MessageBus.publish("/reviewable_claimed", data, user_ids: user_ids)
  end
end
