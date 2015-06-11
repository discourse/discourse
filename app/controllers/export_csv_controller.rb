class ExportCsvController < ApplicationController

  skip_before_filter :preload_json, :check_xhr, only: [:show]

  def export_entity
    params.require(:entity)
    params.require(:entity_type)
    guardian.ensure_can_export_entity!(params[:entity_type])

    Jobs.enqueue(:export_csv_file, entity: params[:entity], user_id: current_user.id)
    render json: success_json
  end

  # download
  def show
    params.require(:id)
    filename = params.fetch(:id)
    export_id = filename.split('-')[-1].split('.')[0]
    export_initiated_by_user_id = 0
    export_initiated_by_user_id = UserExport.where(id: export_id)[0].user_id unless UserExport.where(id: export_id).empty?
    export_csv_path = UserExport.get_download_path(filename)

    if export_csv_path && current_user.present? && export_initiated_by_user_id == current_user.id
      send_file export_csv_path
    else
      render nothing: true, status: 404
    end
  end

end
