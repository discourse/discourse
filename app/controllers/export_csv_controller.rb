class ExportCsvController < ApplicationController

  skip_before_filter :preload_json, :check_xhr, only: [:show]

  def export_entity
    guardian.ensure_can_export_entity!(export_params[:entity_type])
    Jobs.enqueue(:export_csv_file, entity: export_params[:entity], user_id: current_user.id, args: export_params[:args])
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

  private

    def export_params
      @_export_params ||= begin
        params.require(:entity)
        params.require(:entity_type)
        params.permit(:entity, :entity_type, args: [:name, :start_date, :end_date, :category_id])
      end
    end
end
