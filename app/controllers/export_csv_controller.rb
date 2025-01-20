# frozen_string_literal: true

class ExportCsvController < ApplicationController
  skip_before_action :preload_json, :check_xhr, only: [:show]

  def export_entity
    entity = export_params[:entity]
    entity_id = params.dig(:args, :export_user_id)&.to_i if entity == "user_archive"
    guardian.ensure_can_export_entity!(entity, entity_id)
    raise Discourse::InvalidParameters.new(:entity) unless entity.is_a?(String) && entity.size < 100

    (export_params[:args] || {}).each do |key, value|
      unless value.is_a?(String) && value.size < 100
        raise Discourse::InvalidParameters.new("args.#{key}")
      end
    end

    if entity == "user_archive"
      requesting_user_id = current_user.id if entity_id
      admin = { requesting_user_id: requesting_user_id }
      if params[:args].present?
        admin[:send_to_user] = params[:args][:send_to_user] == "true"
        admin[:send_to_admin] = params[:args][:send_to_admin] == "true"
        admin[:send_to_site_contact] = params[:args][:send_to_site_contact] == "true"
      end
      Jobs.enqueue(
        :export_user_archive,
        user_id: entity_id || current_user.id,
        args: export_params[:args],
        admin:,
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

  private

  def export_params
    @_export_params ||=
      begin
        params.require(:entity)
        params.permit(:entity, args: Report::FILTERS).to_h
      end
  end
end
