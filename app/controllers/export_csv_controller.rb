class ExportCsvController < ApplicationController

  skip_before_filter :check_xhr, only: [:show]

  def export_entity
    params.require(:entity)
    params.require(:entity_type)
    if params[:entity_type] == "admin"
      guardian.ensure_can_export_admin_entity!(current_user)
    end

    Jobs.enqueue(:export_csv_file, entity: params[:entity], user_id: current_user.id)
    render json: success_json
  end

  # download
  def show
    params.require(:entity)
    params.require(:file_id)
    if params[:entity] == "system"
      guardian.ensure_can_export_admin_entity!(current_user)
    end

    filename = params.fetch(:file_id)
    if export_csv_path = ExportCsv.get_download_path(filename)
      send_file export_csv_path
    else
      render nothing: true, status: 404
    end
  end

end
