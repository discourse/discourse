class Admin::BadgesController < Admin::AdminController

  def index
    data = {
      badge_types: BadgeType.all.order(:id).to_a,
      badge_groupings: BadgeGrouping.all.order(:position).to_a,
      badges: Badge.includes(:badge_grouping)
        .includes(:badge_type)
        .references(:badge_grouping)
        .order('badge_groupings.position, badge_type_id, badges.name').to_a,
      protected_system_fields: Badge.protected_system_fields,
      triggers: Badge.trigger_hash
    }
    render_serialized(OpenStruct.new(data), AdminBadgesSerializer)
  end

  def preview
    unless SiteSetting.enable_badge_sql
      return render json: "preview not allowed", status: 403
    end

    render json: BadgeGranter.preview(params[:sql],
                                      target_posts: params[:target_posts] == "true",
                                      explain: params[:explain] == "true",
                                      trigger: params[:trigger].to_i)
  end

  def new
  end

  def show
  end

  def badge_types
    badge_types = BadgeType.all.to_a
    render_serialized(badge_types, BadgeTypeSerializer, root: "badge_types")
  end

  def save_badge_groupings
    badge_groupings = BadgeGrouping.all.order(:position).to_a
    ids = params[:ids].map(&:to_i)

    params[:names].each_with_index do |name, index|
      id = ids[index].to_i
      group = badge_groupings.find { |b| b.id == id } || BadgeGrouping.new
      group.name = name
      group.position = index
      group.save
    end

    badge_groupings.each do |g|
      g.destroy unless g.system? || ids.include?(g.id)
    end

    badge_groupings = BadgeGrouping.all.order(:position).to_a
    render_serialized(badge_groupings, BadgeGroupingSerializer, root: "badge_groupings")
  end

  def create
    badge = Badge.new
    errors = update_badge_from_params(badge, new: true)

    if errors.present?
      render_json_error errors
    else
      StaffActionLogger.new(current_user).log_badge_creation(badge)
      render_serialized(badge, AdminBadgeSerializer, root: "badge")
    end
  end

  def update
    badge = find_badge
    errors = update_badge_from_params(badge)

    if errors.present?
      render_json_error errors
    else
      StaffActionLogger.new(current_user).log_badge_change(badge)
      render_serialized(badge, AdminBadgeSerializer, root: "badge")
    end
  end

  def destroy
    badge = find_badge
    StaffActionLogger.new(current_user).log_badge_deletion(badge)
    badge.destroy
    render body: nil
  end

  private
  def find_badge
    params.require(:id)
    Badge.find(params[:id])
  end

  # Options:
  #   :new - reset the badge id to nil before saving
  def update_badge_from_params(badge, opts = {})
    errors = []
    Badge.transaction do
      allowed  = Badge.column_names.map(&:to_sym)
      allowed -= [:id, :created_at, :updated_at, :grant_count]
      allowed -= Badge.protected_system_fields if badge.system?
      allowed -= [:query] unless SiteSetting.enable_badge_sql

      params.permit(*allowed)

      allowed.each do |key|
        badge.send("#{key}=" , params[key]) if params[key]
      end

      # Badge query contract checks
      begin
        if SiteSetting.enable_badge_sql
          BadgeGranter.contract_checks!(badge.query, target_posts: badge.target_posts, trigger: badge.trigger)
        end
      rescue => e
        errors << e.message
        raise ActiveRecord::Rollback
      end

      badge.id = nil if opts[:new]
      badge.save!
    end

    errors
  rescue ActiveRecord::RecordInvalid
    errors.push(*badge.errors.full_messages)
    errors
  end
end
