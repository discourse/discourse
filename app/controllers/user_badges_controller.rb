# frozen_string_literal: true

class UserBadgesController < ApplicationController
  before_action :ensure_badges_enabled

  def index
    params.permit [:granted_before, :offset, :username]

    badge = fetch_badge_from_params
    user_badges = badge.user_badges.order('granted_at DESC, id DESC').limit(96)
    user_badges = user_badges.includes(:user, :granted_by, badge: :badge_type, post: :topic, user: :primary_group)

    grant_count = nil

    if params[:username]
      user_id = User.where(username_lower: params[:username].downcase).pluck_first(:id)
      user_badges = user_badges.where(user_id: user_id) if user_id
      grant_count = badge.user_badges.where(user_id: user_id).count
    end

    if offset = params[:offset]
      user_badges = user_badges.offset(offset.to_i)
    end

    user_badges = UserBadges.new(user_badges: user_badges,
                                 username: params[:username],
                                 grant_count: grant_count)

    render_serialized(user_badges, UserBadgesSerializer, root: :user_badge_info, include_long_description: true)
  end

  def username
    params.permit [:grouped]

    user = fetch_user_from_params(include_inactive: current_user.try(:staff?) || (current_user && SiteSetting.show_inactive_accounts))
    user_badges = user.user_badges

    if params[:grouped]
      user_badges = user_badges.group(:badge_id)
        .select(UserBadge.attribute_names.map { |x| "MAX(#{x}) AS #{x}" }, 'COUNT(*) AS "count"')
    end

    user_badges = user_badges.includes(badge: [:badge_grouping, :badge_type])
      .includes(post: :topic)
      .includes(:granted_by)

    render_serialized(user_badges, DetailedUserBadgeSerializer, root: :user_badges)
  end

  def create
    params.require(:username)
    user = fetch_user_from_params

    unless can_assign_badge_to_user?(user)
      return render json: failed_json, status: 403
    end

    badge = fetch_badge_from_params
    post_id = nil

    if params[:reason].present?
      unless is_badge_reason_valid? params[:reason]
        return render json: failed_json.merge(message: I18n.t('invalid_grant_badge_reason_link')), status: 400
      end

      if route = Discourse.route_for(params[:reason])
        topic_id = route[:topic_id].to_i
        post_number = route[:post_number] || 1

        post_id = Post.find_by(topic_id: topic_id, post_number: post_number).try(:id) if topic_id > 0
      end
    end

    user_badge = BadgeGranter.grant(badge, user, granted_by: current_user, post_id: post_id)

    render_serialized(user_badge, DetailedUserBadgeSerializer, root: "user_badge")
  end

  def destroy
    params.require(:id)
    user_badge = UserBadge.find(params[:id])

    unless can_assign_badge_to_user?(user_badge.user)
      render json: failed_json, status: 403
      return
    end

    BadgeGranter.revoke(user_badge, revoked_by: current_user)
    render json: success_json
  end

  private

  # Get the badge from either the badge name or id specified in the params.
  def fetch_badge_from_params
    badge = nil

    params.permit(:badge_name)
    if params[:badge_name].nil?
      params.require(:badge_id)
      badge = Badge.find_by(id: params[:badge_id], enabled: true)
    else
      badge = Badge.find_by(name: params[:badge_name], enabled: true)
    end
    raise Discourse::NotFound if badge.blank?

    badge
  end

  def can_assign_badge_to_user?(user)
    master_api_call = current_user.nil? && is_api?
    master_api_call || guardian.can_grant_badges?(user)
  end

  def ensure_badges_enabled
    raise Discourse::NotFound unless SiteSetting.enable_badges?
  end

  def is_badge_reason_valid?(reason)
    route = Discourse.route_for(reason)
    route && (route[:controller] == 'posts' || route[:controller] == 'topics')
  end
end
