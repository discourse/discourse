class Admin::ExportController < Admin::AdminController
  def create
    unless Export.is_export_running? || Import.is_import_running?
      job_id = Jobs.enqueue( :exporter, user_id: current_user.id )
      render json: success_json.merge( job_id: job_id )
    else
      render json: failed_json.merge( message: "An #{Export.is_export_running? ? 'export' : 'import'} is currently running. Can't start a new export job right now.")
    end
  end
end
