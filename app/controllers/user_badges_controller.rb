# frozen_string_literal: true

class UserBadgesController < ApplicationController
  MAX_BADGES = 96 # This was limited in PR#2360 to make it divisible by 8
  MAX_INDEX_LIMIT = 50

  before_action :ensure_badges_enabled
  before_action :ensure_logged_in, only: %i[create destroy toggle_favorite]

  def index
    params.permit %i[
                    granted_before
                    offset
                    username
                    badge_id
                    badge_name
                    badge_ids
                    badge_type_id
                    limit
                  ]

    user_badges = scoped_user_badges

    grant_count = nil

    if params[:username]
      user = fetch_user_from_params(include_inactive: true)
      raise Discourse::NotFound unless guardian.can_see_profile?(user)

      user_badges = user_badges.where(user_id: user.id)
      grant_count = user_badges.count
    end

    user_badges =
      user_badges
        .order("granted_at DESC, id DESC")
        .limit(index_limit)
        .includes(
          :user,
          :granted_by,
          badge: :badge_type,
          post: :topic,
          user: %i[primary_group flair_group],
        )

    offset = fetch_int_from_params(:offset, default: 0)
    user_badges = user_badges.offset(offset) if offset > 0

    user_badges_topic_ids = user_badges.map { |user_badge| user_badge.post&.topic_id }.compact

    user_badges =
      UserBadges.new(
        user_badges: user_badges,
        username: params[:username],
        grant_count: grant_count,
      )

    render_serialized(
      user_badges,
      UserBadgesSerializer,
      root: :user_badge_info,
      include_long_description: true,
      allowed_user_badge_topic_ids: guardian.can_see_topic_ids(topic_ids: user_badges_topic_ids),
    )
  end

  def username
    params.permit [:grouped]

    user =
      fetch_user_from_params(
        include_inactive:
          current_user.try(:staff?) || (current_user && SiteSetting.show_inactive_accounts),
      )
    raise Discourse::NotFound unless guardian.can_see_profile?(user)
    user_badges = user.user_badges

    user_badges = user_badges.group(:badge_id).select_for_grouping if params[:grouped]

    user_badges =
      user_badges
        .includes(badge: %i[badge_grouping badge_type image_upload])
        .includes(post: :topic)
        .includes(:granted_by)

    user_badges_topic_ids = user_badges.map { |user_badge| user_badge.post&.topic_id }.compact

    render_serialized(
      user_badges,
      DetailedUserBadgeSerializer,
      allowed_user_badge_topic_ids: guardian.can_see_topic_ids(topic_ids: user_badges_topic_ids),
      root: :user_badges,
    )
  end

  def create
    params.require(:username)
    user = fetch_user_from_params

    return render json: failed_json, status: :forbidden unless can_assign_badge_to_user?(user)

    badge = fetch_badge_from_params
    post_id = nil

    if params[:reason].present?
      unless is_badge_reason_valid? params[:reason]
        return(
          render json: failed_json.merge(message: I18n.t("invalid_grant_badge_reason_link")),
                 status: :bad_request
        )
      end

      if route = Discourse.route_for(params[:reason])
        if (route[:controller] == "topics" && route[:action] == "show") ||
             route[:controller] == "nested_topics"
          topic_id = (route[:id] || route[:topic_id]).to_i
          post_number = route[:post_number] || 1
          post_id = Post.find_by(topic_id: topic_id, post_number: post_number)&.id if topic_id > 0
        end
      end
    end

    grant_opts_from_params =
      DiscoursePluginRegistry.apply_modifier(
        :user_badges_badge_grant_opts,
        { granted_by: current_user, post_id: post_id },
        { param: params },
      )

    user_badge = BadgeGranter.grant(badge, user, grant_opts_from_params)

    render_serialized(user_badge, DetailedUserBadgeSerializer, root: "user_badge")
  end

  def destroy
    params.require(:id)
    user_badge = UserBadge.find(params[:id])

    unless can_assign_badge_to_user?(user_badge.user)
      render json: failed_json, status: :forbidden
      return
    end

    BadgeGranter.revoke(user_badge, revoked_by: current_user)
    render json: success_json
  end

  def toggle_favorite
    params.require(:user_badge_id)
    user_badge = UserBadge.find(params[:user_badge_id])
    user_badges = user_badge.user.user_badges

    return render json: failed_json, status: :forbidden unless can_favorite_badge?(user_badge)

    is_favorite = user_badges.where(badge: user_badge.badge, is_favorite: true).exists?

    if !is_favorite &&
         user_badges.select(:badge_id).distinct.where(is_favorite: true).count >=
           SiteSetting.max_favorite_badges
      return render json: failed_json, status: :bad_request
    end

    UserBadge.where(user_id: user_badge.user_id, badge_id: user_badge.badge_id).update_all(
      is_favorite: !is_favorite,
    )
    UserBadge.update_featured_ranks!([user_badge.user_id])
  end

  private

  def scoped_user_badges
    ids = selected_badge_ids

    scope =
      if ids
        UserBadge.where(badge: Badge.enabled).where(badge_id: ids)
      else
        UserBadge.where(badge: Badge.enabled.where(listable: true))
      end

    if params[:badge_type_id].present?
      type_id = fetch_int_from_params(:badge_type_id, default: nil, min: 1)
      scope = scope.joins(:badge).where(badges: { badge_type_id: type_id })
    end

    scope
  end

  def selected_badge_ids
    return parse_badge_ids(params[:badge_ids]) if params.key?(:badge_ids)

    if params[:badge_name].present?
      badge = Badge.find_by(name: params[:badge_name], enabled: true)
      raise Discourse::NotFound if badge.blank?

      return [badge.id]
    end

    if params[:badge_id].present?
      badge = Badge.find_by(id: params[:badge_id], enabled: true)
      raise Discourse::NotFound if badge.blank?

      return [badge.id]
    end

    nil
  end

  def parse_badge_ids(raw)
    return nil if raw.blank?

    tokens = raw.is_a?(Array) ? raw.flatten : raw.to_s.split(/[,|\s+]/)
    tokens
      .flat_map { |token| token.to_s.split(/[,|\s+]/) }
      .filter_map { |token| Integer(token, exception: false) }
      .select(&:positive?)
      .uniq
  end

  def index_limit
    limit = fetch_int_from_params(:limit, min: 1, default: MAX_BADGES)
    [limit, MAX_INDEX_LIMIT].min
  end

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

  def can_favorite_badge?(user_badge)
    current_user == user_badge.user && !(1..4).include?(user_badge.badge_id)
  end

  def ensure_badges_enabled
    raise Discourse::NotFound unless SiteSetting.enable_badges?
  end

  def is_badge_reason_valid?(reason)
    route = Discourse.route_for(reason)
    route &&
      (
        route[:controller] == "posts" || route[:controller] == "topics" ||
          route[:controller] == "nested_topics"
      )
  end
end
