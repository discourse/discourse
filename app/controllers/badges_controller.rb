class BadgesController < ApplicationController
  skip_before_filter :check_xhr, only: [:index, :show]

  def index
    raise Discourse::NotFound unless SiteSetting.enable_badges

    badges = Badge.all

    if (params[:only_listable] == "true") || !request.xhr?
      # NOTE: this is sorted client side if needed
      badges = badges.includes(:badge_grouping)
                     .where(enabled: true, listable: true)

    end

    badges = badges.to_a

    user_badges = nil
    if current_user
      user_badges = Set.new(current_user.user_badges.select('distinct badge_id').pluck(:badge_id))
    end
    serialized = MultiJson.dump(serialize_data(badges, BadgeIndexSerializer, root: "badges", user_badges: user_badges, include_long_description: true))
    respond_to do |format|
      format.html do
        store_preloaded "badges", serialized
        render "default/empty"
      end
      format.json { render json: serialized }
    end
  end

  def show
    raise Discourse::NotFound unless SiteSetting.enable_badges

    params.require(:id)
    badge = Badge.enabled.find(params[:id])

    if current_user
      user_badge = UserBadge.find_by(user_id: current_user.id, badge_id: badge.id)
      if user_badge && user_badge.notification
        user_badge.notification.update_attributes read: true
      end
    end

    serialized = MultiJson.dump(serialize_data(badge, BadgeSerializer, root: "badge", include_long_description: true))
    respond_to do |format|
      format.html do
        store_preloaded "badge", serialized
        render "default/empty"
      end
      format.json { render json: serialized }
    end
  end
end
