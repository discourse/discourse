require_dependency "backup_restore"

class Admin::BackupsController < Admin::AdminController

  skip_before_filter :check_xhr, only: [:index, :show]

  def index
    respond_to do |format|
      format.html do
        store_preloaded("backups", MultiJson.dump(serialize_data(Backup.all, BackupSerializer)))
        store_preloaded("operations_status", MultiJson.dump(BackupRestore.operations_status))
        render "default/empty"
      end
      format.json do
        render_serialized(Backup.all, BackupSerializer)
      end
    end
  end

  def status
    render_json_dump(BackupRestore.operations_status)
  end

  def create
    BackupRestore.backup!(current_user.id, true)
  rescue BackupRestore::OperationRunningError
    render json: failed_json.merge(message: I18n.t("backup.operation_already_running"))
  else
    render json: success_json
  end

  def cancel
    BackupRestore.cancel!
  rescue BackupRestore::OperationRunningError
    render json: failed_json.merge(message: I18n.t("backup.operation_already_running"))
  else
    render json: success_json
  end

  # download
  def show
    filename = params.fetch(:id)
    if backup = Backup[filename]
      send_file backup.path
    else
      render nothing: true, status: 404
    end
  end

  def destroy
    filename = params.fetch(:id)
    Backup.remove(filename)
    render nothing: true
  end

  def logs
    store_preloaded("operations_status", MultiJson.dump(BackupRestore.operations_status))
    render "default/empty"
  end

  def restore
    filename = params.fetch(:id)
    BackupRestore.restore!(current_user.id, filename, true)
  rescue BackupRestore::OperationRunningError
    render json: failed_json.merge(message: I18n.t("backup.operation_already_running"))
  else
    render json: success_json
  end

  def rollback
    BackupRestore.rollback!
  rescue BackupRestore::OperationRunningError
    render json: failed_json.merge(message: I18n.t("backup.operation_already_running"))
  else
    render json: success_json
  end

  def readonly
    enable = params.fetch(:enable).to_s == "true"
    enable ? Discourse.enable_readonly_mode : Discourse.disable_readonly_mode
    render nothing: true
  end

end
