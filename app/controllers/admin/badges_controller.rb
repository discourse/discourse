class Admin::BadgesController < Admin::AdminController
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
      allowed = [:icon, :name, :description, :badge_type_id, :allow_title, :multiple_grant, :listable, :enabled, :badge_grouping_id]
      params.permit(*allowed)

      allowed.each do |key|
        badge.send("#{key}=" , params[key]) if params[key]
      end

      badge
    end
end
