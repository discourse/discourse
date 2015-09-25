class UserBadgesController < ApplicationController
  def index
    params.permit [:granted_before, :offset]

    badge = fetch_badge_from_params
    user_badges = badge.user_badges.order('granted_at DESC, id DESC').limit(96)
    user_badges = user_badges.includes(:user, :granted_by, badge: :badge_type, post: :topic)

    if offset = params[:offset]
      user_badges = user_badges.offset(offset.to_i)
    end

    render_serialized(user_badges, UserBadgeSerializer, root: "user_badges", include_long_description: true)
  end

  def username
    params.permit [:grouped]

    user = fetch_user_from_params
    user_badges = user.user_badges

    if params[:grouped]
      user_badges = user_badges.group(:badge_id)
                               .select(UserBadge.attribute_names.map {|x| "MAX(#{x}) as #{x}" }, 'COUNT(*) as count')
    end

    user_badges = user_badges.includes(badge: [:badge_grouping, :badge_type])
                             .includes(post: :topic)
                             .includes(:granted_by)

    render_serialized(user_badges, DetailedUserBadgeSerializer, root: "user_badges")
  end

  def create
    params.require(:username)
    user = fetch_user_from_params

    unless can_assign_badge_to_user?(user)
      render json: failed_json, status: 403
      return
    end

    badge = fetch_badge_from_params
    post_id = nil

    if params[:reason].present?
      path = URI.parse(params[:reason]).path rescue nil
      route = Rails.application.routes.recognize_path(path) if path
      if route
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
      master_api_call or guardian.can_grant_badges?(user)
    end
end
