class UserBadgesController < ApplicationController
  def index
    params.permit(:username).permit(:granted_before)

    if params[:username]
      user = fetch_user_from_params
      user_badges = user.user_badges
    else
      badge = fetch_badge_from_params
      user_badges = badge.user_badges.order('granted_at DESC').limit(96)
    end

    if params[:granted_before]
      user_badges = user_badges.where('granted_at < ?', Time.at(params[:granted_before].to_f))
    end

    user_badges = user_badges.includes(:user, :granted_by, badge: :badge_type, post: :topic)

    if params[:grouped]
      user_badges = user_badges.group(:badge_id).select(UserBadge.attribute_names.map {|x| "MAX(#{x}) as #{x}" }, 'COUNT(*) as count')
    end

    render_serialized(user_badges, UserBadgeSerializer, root: "user_badges")
  end

  def create
    params.require(:username)
    user = fetch_user_from_params

    unless can_assign_badge_to_user?(user)
      render json: failed_json, status: 403
      return
    end

    badge = fetch_badge_from_params
    user_badge = BadgeGranter.grant(badge, user, granted_by: current_user)

    render_serialized(user_badge, UserBadgeSerializer, root: "user_badge")
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
        badge = Badge.find_by(id: params[:badge_id])
      else
        badge = Badge.find_by(name: params[:badge_name])
      end
      raise Discourse::NotFound.new if badge.blank?

      badge
    end

    def can_assign_badge_to_user?(user)
      master_api_call = current_user.nil? && is_api?
      master_api_call or guardian.can_grant_badges?(user)
    end
end
