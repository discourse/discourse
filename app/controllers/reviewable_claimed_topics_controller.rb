# frozen_string_literal: true

class ReviewableClaimedTopicsController < ApplicationController
  requires_login

  def create
    topic = Topic.with_deleted.find_by(id: params[:reviewable_claimed_topic][:topic_id])
    automatic = params[:reviewable_claimed_topic][:automatic] == "true"
    guardian.ensure_can_claim_reviewable_topic!(topic, automatic)

    begin
      ReviewableClaimedTopic.create!(user_id: current_user.id, topic_id: topic.id, automatic:)
    rescue ActiveRecord::RecordInvalid
      return render_json_error(I18n.t("reviewables.conflict"), status: 409)
    end

    topic.reviewables.find_each { |reviewable| reviewable.log_history(:claimed, current_user) }

    notify_users(topic, current_user, automatic)
    render json: success_json
  end

  def destroy
    topic = Topic.with_deleted.find_by(id: params[:id])
    automatic = params[:automatic] == "true"
    raise Discourse::NotFound if topic.blank?

    guardian.ensure_can_claim_reviewable_topic!(topic, automatic)
    ReviewableClaimedTopic.where(topic_id: topic.id).delete_all
    topic.reviewables.find_each { |reviewable| reviewable.log_history(:unclaimed, current_user) }

    notify_users(topic, nil, automatic)
    render json: success_json
  end

  private

  def notify_users(topic, claimed_by, automatic)
    group_ids = Set.new([Group::AUTO_GROUPS[:staff]])

    if SiteSetting.enable_category_group_moderation? && topic.category
      group_ids.merge(topic.category.moderating_group_ids)
    end

    if claimed_by.present?
      data = {
        topic_id: topic.id,
        user: BasicUserSerializer.new(claimed_by, root: false).as_json,
        automatic:,
      }
    else
      data = { topic_id: topic.id, automatic: }
    end

    MessageBus.publish("/reviewable_claimed", data, group_ids: group_ids.to_a)

    Jobs.enqueue(:refresh_users_reviewable_counts, group_ids: group_ids.to_a)
  end
end
