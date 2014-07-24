class Admin::BadgesController < Admin::AdminController

  def index
    data = {
      badge_types: BadgeType.all.to_a,
      badge_groupings: BadgeGrouping.all.to_a,
      badges: Badge.all.to_a,
      protected_system_fields: Badge.protected_system_fields,
      triggers: Badge.trigger_hash
    }
    render_serialized(OpenStruct.new(data), AdminBadgesSerializer)
  end

  def preview
    render json: BadgeGranter.preview(params[:sql], target_posts: params[:target_posts] == "true")
  end

  def badge_types
    badge_types = BadgeType.all.to_a
    render_serialized(badge_types, BadgeTypeSerializer, root: "badge_types")
  end

  def badge_groupings
    badge_groupings = BadgeGrouping.all.to_a
    render_serialized(badge_groupings, BadgeGroupingSerializer, root: "badge_groupings")
  end

  def create
    badge = Badge.new
    update_badge_from_params(badge)
    badge.save!
    render_serialized(badge, BadgeSerializer, root: "badge")
  end

  def update
    badge = find_badge
    update_badge_from_params(badge)
    badge.save!
    render_serialized(badge, BadgeSerializer, root: "badge")
  end

  def destroy
    find_badge.destroy
    render nothing: true
  end

  private
    def find_badge
      params.require(:id)
      Badge.find(params[:id])
    end

    def update_badge_from_params(badge)
      allowed = Badge.column_names.map(&:to_sym)
      allowed -= [:id, :created_at, :updated_at, :grant_count]
      allowed -= Badge.protected_system_fields if badge.system?
      params.permit(*allowed)

      allowed.each do |key|
        badge.send("#{key}=" , params[key]) if params[key]
      end

      badge
    end
end
