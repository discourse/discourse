# frozen_string_literal: true

class ExportCsvController < ApplicationController
  requires_login
  skip_before_action :preload_json, :check_xhr, only: [:show]

  def export_entity
    entity = export_params[:entity]
    entity_id = params.dig(:args, :export_user_id)&.to_i if entity == "user_archive"
    guardian.ensure_can_export_entity!(entity, entity_id, export_params[:args])
    raise Discourse::InvalidParameters.new(:entity) unless entity.is_a?(String) && entity.size < 100

    (export_params[:args] || {}).each do |key, value|
      unless value.is_a?(String) && value.size < 100
        raise Discourse::InvalidParameters.new("args.#{key}")
      end
    end

    if entity == "user_archive"
      archive_user_id = entity_id || current_user.id
      requesting_user_id = current_user.id if entity_id

      # Rate limit user archive exports to 1 per day
      unless current_user.admin || reserve_user_archive_export!(archive_user_id)
        render_json_error I18n.t("csv_export.rate_limit_error")
        return
      end

      reserve_user_archive_export!(archive_user_id) if current_user.admin

      Jobs.enqueue(
        :export_user_archive,
        user_id: archive_user_id,
        requesting_user_id:,
        args: export_params[:args],
      )
    else
      Jobs.enqueue(
        :export_csv_file,
        entity: entity,
        user_id: current_user.id,
        args: export_params[:args],
      )
    end
    StaffActionLogger.new(current_user).log_entity_export(entity)
    render json: success_json
  rescue Discourse::InvalidAccess
    render_json_error I18n.t("csv_export.rate_limit_error")
  end

  def latest_user_archive
    user_id = params[:user_id].to_i
    # If we can't export the entity, we shouldn't be able to see it either
    guardian.ensure_can_export_entity!("user_archive", user_id)

    render json:
             UserExport
               .where(user_id:)
               .where("created_at > ?", UserExport::DESTROY_CREATED_BEFORE.ago)
               .order(created_at: :desc)
               .first
  end

  private

  def reserve_user_archive_export!(user_id)
    return false if UserExport.exists?(user_id: user_id, created_at: Time.zone.now.all_day)

    Discourse.redis.set(
      user_archive_export_rate_limit_key(user_id),
      "1",
      nx: true,
      ex: seconds_until_tomorrow,
    )
  end

  def user_archive_export_rate_limit_key(user_id)
    "user_archive_export_rate_limit:#{user_id}:#{Time.zone.today}"
  end

  def seconds_until_tomorrow
    now = Time.zone.now
    [(now.end_of_day - now).ceil, 1].max
  end

  def export_params
    @_export_params ||=
      begin
        params.require(:entity)
        params.permit(:entity, args: [*Report::FILTERS, *UserHistory.staff_filters]).to_h
      end
  end
end
