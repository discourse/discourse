class BadgesController < ApplicationController
  skip_before_filter :check_xhr, only: [:index, :show]

  def index
    badges = Badge.all
    badges = badges.where(listable: true) if(params[:only_listable] == "true") || !request.xhr?
    badges = badges.to_a
    serialized = MultiJson.dump(serialize_data(badges, BadgeSerializer, root: "badges"))
    respond_to do |format|
      format.html do
        store_preloaded "badges", serialized
        render "default/empty"
      end
      format.json { render json: serialized }
    end
  end

  def show
    params.require(:id)
    badge = Badge.find(params[:id])

    if current_user
      user_badge = UserBadge.find_by(user_id: current_user.id, badge_id: badge.id)
      if user_badge && user_badge.notification
        user_badge.notification.update_attributes read: true
      end
    end

    serialized = MultiJson.dump(serialize_data(badge, BadgeSerializer, root: "badge"))
    respond_to do |format|
      format.html do
        store_preloaded "badge", serialized
        render "default/empty"
      end
      format.json { render json: serialized }
    end
  end
end
