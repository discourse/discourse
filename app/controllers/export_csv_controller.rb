# frozen_string_literal: true

class ExportCsvController < ApplicationController

  skip_before_action :preload_json, :check_xhr, only: [:show]

  def export_entity
    guardian.ensure_can_export_entity!(export_params[:entity])
    Jobs.enqueue(:export_csv_file, entity: export_params[:entity], user_id: current_user.id, args: export_params[:args])
    StaffActionLogger.new(current_user).log_entity_export(export_params[:entity])
    render json: success_json
  rescue Discourse::InvalidAccess
    render_json_error I18n.t("csv_export.rate_limit_error")
  end

  private

  def export_params
    @_export_params ||= begin
      params.require(:entity)
      params.permit(:entity, args: [:name, :start_date, :end_date, :category_id, :group_id, :trust_level]).to_h
    end
  end
end
