class BadgesController < ApplicationController
  skip_before_filter :check_xhr, only: [:index, :show]

  def index
    badges = get_badge
    
    user_badges = current_user.nil? \
                  ? nil 
                  : Set.new(current_user.user_badges.select('distinct badge_id').pluck(:badge_id))
    
    serialized = MultiJson.dump(serialize_data(badges, BadgeIndexSerializer, root: "badges", user_badges: user_badges))
    
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
    badge = Badge.enabled.find(params[:id])

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
  
  private
  def get_badge
    if (params[:only_listable] == "true") || !request.xhr?
      # NOTE: this is sorted client side if needed
      return Badge.all.includes(:badge_grouping)
                     .where(enabled: true, listable: true).to_a
    end
    
    return Badge.all.to_a
  end
end
