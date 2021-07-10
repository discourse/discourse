# frozen_string_literal: true

require 'csv'

class Admin::BadgesController < Admin::AdminController
  MAX_CSV_LINES = 50_000
  BATCH_SIZE = 200

  def index
    data = {
      badge_types: BadgeType.all.order(:id).to_a,
      badge_groupings: BadgeGrouping.all.order(:position).to_a,
      badges: Badge.includes(:badge_grouping)
        .includes(:badge_type, :image_upload)
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

  def award
  end

  def mass_award
    csv_file = params.permit(:file).fetch(:file, nil)
    badge = Badge.find_by(id: params[:badge_id])
    raise Discourse::InvalidParameters if csv_file.try(:tempfile).nil? || badge.nil?

    if !badge.enabled?
      render_json_error(
        I18n.t('badges.mass_award.errors.badge_disabled', badge_name: badge.display_name),
        status: 422
      )
      return
    end

    replace_badge_owners = params[:replace_badge_owners] == 'true'
    grant_existing_holders = params[:grant_existing_holders] == 'true'
    if grant_existing_holders && !badge.multiple_grant?
      render_json_error(
        I18n.t('badges.mass_award.errors.cant_grant_multiple_times', badge_name: badge.display_name),
        status: 422
      )
      return
    end

    BadgeGranter.revoke_all(badge) if replace_badge_owners

    line_number = 1
    count_per_user = {}
    File.open(csv_file) do |csv|
      email_mode = Email.is_valid?(CSV.parse_line(csv.first).first)
      csv.rewind

      batch = []
      total_entries = 0
      csv.each_line do |line|
        line = CSV.parse_line(line).first&.strip&.downcase
        line_number += 1

        if line.present?
          batch << (email_mode ? line : User.normalize_username(line))
          total_entries += 1
        end

        if total_entries > MAX_CSV_LINES
          return render_json_error I18n.t('badges.mass_award.errors.too_many_csv_entries', count: MAX_CSV_LINES), status: 400
        end

        last_batch_item = (total_entries % BATCH_SIZE == 0) || csv.eof?

        if last_batch_item
          if email_mode
            users = User.with_email(batch).pluck('LOWER(user_emails.email)', :id).to_h
          else
            users = User.where(username_lower: batch).pluck(:username_lower, :id).to_h
          end
          batch.each do |entry|
            user_id = users[entry]
            if grant_existing_holders
              count_per_user[user_id] ||= 0
              count_per_user[user_id] += 1
            else
              count_per_user[user_id] = 1
            end
          end
          batch = []
        end
      end
    end

    count_per_user.each do |user_id, count|
      Jobs.enqueue(
        :mass_award_badge,
        user: user_id,
        badge: badge.id,
        count: count,
        grant_existing_holders: grant_existing_holders
      )
    end

    head :ok
  rescue CSV::MalformedCSVError
    render_json_error I18n.t('badges.mass_award.errors.invalid_csv', line_number: line_number), status: 400
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
    Badge.transaction do
      badge = find_badge
      StaffActionLogger.new(current_user).log_badge_deletion(badge)
      badge.clear_user_titles!
      badge.destroy!
    end
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
        badge.public_send("#{key}=" , params[key]) if params[key]
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

    if opts[:new].blank?
      Jobs.enqueue(
        :bulk_user_title_update,
        new_title: badge.name,
        granted_badge_id: badge.id,
        action: Jobs::BulkUserTitleUpdate::UPDATE_ACTION
      )
    end

    errors
  rescue ActiveRecord::RecordInvalid
    errors.push(*badge.errors.full_messages)
    errors
  end
end
