class Admin::ExportCsvController < Admin::AdminController

  skip_before_filter :check_xhr, only: [:show]

  def export_user_list
    # export csv file in a background thread
    Jobs.enqueue(:export_csv_file, entity: 'user', user_id: current_user.id)
    render json: success_json
  end

  # download
  def show
    filename = params.fetch(:id)
    if export_csv_path = ExportCsv.get_download_path(filename)
      send_file export_csv_path
    else
      render nothing: true, status: 404
    end
  end

end
