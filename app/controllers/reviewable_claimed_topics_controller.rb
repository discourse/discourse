# frozen_string_literal: true

class ReviewableClaimedTopicsController < ApplicationController
  requires_login

  def create
    topic = Topic.with_deleted.find_by(id: params[:reviewable_claimed_topic][:topic_id])
    guardian.ensure_can_claim_reviewable_topic!(topic)

    begin
      ReviewableClaimedTopic.create!(user_id: current_user.id, topic_id: topic.id)
    rescue ActiveRecord::RecordInvalid
      return render_json_error(I18n.t("reviewables.conflict"), status: 409)
    end

    topic.reviewables.find_each { |reviewable| reviewable.log_history(:claimed, current_user) }

    notify_users(topic, current_user)
    render json: success_json
  end

  def destroy
    topic = Topic.with_deleted.find_by(id: params[:id])
    raise Discourse::NotFound if topic.blank?

    guardian.ensure_can_claim_reviewable_topic!(topic)
    ReviewableClaimedTopic.where(topic_id: topic.id).delete_all
    topic.reviewables.find_each { |reviewable| reviewable.log_history(:unclaimed, current_user) }

    notify_users(topic, nil)
    render json: success_json
  end

  private

  def notify_users(topic, claimed_by)
    group_ids = Set.new([Group::AUTO_GROUPS[:staff]])

    if SiteSetting.enable_category_group_moderation? &&
         group_id = topic.category&.reviewable_by_group_id.presence
      group_ids.add(group_id)
    end

    if claimed_by.present?
      data = { topic_id: topic.id, user: BasicUserSerializer.new(claimed_by, root: false).as_json }
    else
      data = { topic_id: topic.id }
    end

    MessageBus.publish("/reviewable_claimed", data, group_ids: group_ids.to_a)

    if !SiteSetting.legacy_navigation_menu?
      Jobs.enqueue(:refresh_users_reviewable_counts, group_ids: group_ids.to_a)
    end
  end
end
