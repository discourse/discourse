class Admin::ExportController < Admin::AdminController
  def create
    unless Export.is_export_running? || Import.is_import_running?
      job_id = Jobs.enqueue( :exporter, user_id: current_user.id )
      render json: success_json.merge( job_id: job_id )
    else
      render json: failed_json.merge( message: I18n.t('operation_already_running', { operation: Export.is_export_running? ? 'export' : 'import' }))
    end
  end
end
