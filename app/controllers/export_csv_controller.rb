# frozen_string_literal: true

class ExportCsvController < ApplicationController
  skip_before_action :check_xhr, only: [:show]

  def export_entity
    guardian.ensure_can_export_entity!(export_params[:entity])
    entity = export_params[:entity]
    raise Discourse::InvalidParameters.new(:entity) unless entity.is_a?(String) && entity.size < 100

    (export_params[:args] || {}).each do |key, value|
      unless value.is_a?(String) && value.size < 100
        raise Discourse::InvalidParameters.new("args.#{key}")
      end
    end

    if entity == "user_archive"
      Jobs.enqueue(:export_user_archive, user_id: current_user.id, args: export_params[:args])
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
