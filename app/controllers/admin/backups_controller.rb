require "backup_restore/backup_restore"

class Admin::BackupsController < Admin::AdminController

  skip_before_filter :check_xhr, only: [:index, :show, :logs, :check_backup_chunk, :upload_backup_chunk]

  def index
    respond_to do |format|
      format.html do
        store_preloaded("backups", MultiJson.dump(serialize_data(Backup.all, BackupSerializer)))
        store_preloaded("operations_status", MultiJson.dump(BackupRestore.operations_status))
        store_preloaded("logs", MultiJson.dump(BackupRestore.logs))
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
    opts = {
      publish_to_message_bus: true,
      with_uploads: params.fetch(:with_uploads) == "true",
      client_id: params[:client_id],
    }
    BackupRestore.backup!(current_user.id, opts)
  rescue BackupRestore::OperationRunningError
    render json: failed_json.merge(message: I18n.t("backup.operation_already_running"))
  else
    StaffActionLogger.new(current_user).log_backup_operation
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
      headers['Content-Length'] = File.size(backup.path)
      send_file backup.path
    else
      render nothing: true, status: 404
    end
  end

  def destroy
    backup = Backup[params.fetch(:id)]
    if backup
      backup.remove
      render nothing: true
    else
      render nothing: true, status: 404
    end
  end

  def logs
    store_preloaded("operations_status", MultiJson.dump(BackupRestore.operations_status))
    store_preloaded("logs", MultiJson.dump(BackupRestore.logs))
    render "default/empty"
  end

  def restore
    opts = {
      filename: params.fetch(:id),
      client_id: params.fetch(:client_id),
      publish_to_message_bus: true,
    }
    BackupRestore.restore!(current_user.id, opts)
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

  def check_backup_chunk
    identifier         = params.fetch(:resumableIdentifier)
    filename           = params.fetch(:resumableFilename)
    chunk_number       = params.fetch(:resumableChunkNumber)
    current_chunk_size = params.fetch(:resumableCurrentChunkSize).to_i

    # path to chunk file
    chunk = Backup.chunk_path(identifier, filename, chunk_number)
    # check chunk upload status
    status = HandleChunkUpload.check_chunk(chunk, current_chunk_size: current_chunk_size)

    render nothing: true, status: status
  end

  def upload_backup_chunk
    filename   = params.fetch(:resumableFilename)
    total_size = params.fetch(:resumableTotalSize).to_i

    return render status: 415, text: I18n.t("backup.backup_file_should_be_tar_gz") unless /\.(tar\.gz|t?gz)$/i =~ filename
    return render status: 415, text: I18n.t("backup.not_enough_space_on_disk")     unless has_enough_space_on_disk?(total_size)

    file               = params.fetch(:file)
    identifier         = params.fetch(:resumableIdentifier)
    chunk_number       = params.fetch(:resumableChunkNumber).to_i
    chunk_size         = params.fetch(:resumableChunkSize).to_i
    current_chunk_size = params.fetch(:resumableCurrentChunkSize).to_i

    # path to chunk file
    chunk = Backup.chunk_path(identifier, filename, chunk_number)
    # upload chunk
    HandleChunkUpload.upload_chunk(chunk, file: file)

    uploaded_file_size = chunk_number * chunk_size
    # when all chunks are uploaded
    if uploaded_file_size + current_chunk_size >= total_size
      # merge all the chunks in a background thread
      Jobs.enqueue_in(5.seconds, :backup_chunks_merger, filename: filename, identifier: identifier, chunks: chunk_number)
    end

    render nothing: true
  end

  private

  def has_enough_space_on_disk?(size)
    `df -Pk #{Rails.root}/public/backups | awk 'NR==2 {print $4 * 1024;}'`.to_i > size
  end

end
