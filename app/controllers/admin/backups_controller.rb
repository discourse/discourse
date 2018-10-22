require "backup_restore/backup_restore"
require "backup_restore/backup_store"

class Admin::BackupsController < Admin::AdminController
  before_action :ensure_backups_enabled
  skip_before_action :check_xhr, only: [:index, :show, :logs, :check_backup_chunk, :upload_backup_chunk]

  def index
    respond_to do |format|
      format.html do
        store_preloaded("operations_status", MultiJson.dump(BackupRestore.operations_status))
        store_preloaded("logs", MultiJson.dump(BackupRestore.logs))
        render "default/empty"
      end

      format.json do
        store = BackupRestore::BackupStore.create

        begin
          render_serialized(store.files, BackupFileSerializer)
        rescue BackupRestore::BackupStore::StorageError => e
          render_json_error(e)
        end
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
    StaffActionLogger.new(current_user).log_backup_create
    render json: success_json
  end

  def cancel
    BackupRestore.cancel!
  rescue BackupRestore::OperationRunningError
    render json: failed_json.merge(message: I18n.t("backup.operation_already_running"))
  else
    render json: success_json
  end

  def email
    store = BackupRestore::BackupStore.create

    if store.file(params.fetch(:id)).present?
      Jobs.enqueue(
        :download_backup_email,
        user_id: current_user.id,
        backup_file_path: url_for(controller: 'backups', action: 'show')
      )

      render body: nil
    else
      render body: nil, status: 404
    end
  end

  def show
    if !EmailBackupToken.compare(current_user.id, params.fetch(:token))
      @error = I18n.t('download_backup_mailer.no_token')
      return render template: 'admin/backups/show.html.erb', layout: 'no_ember', status: 422
    end

    store = BackupRestore::BackupStore.create

    if backup = store.file(params.fetch(:id), include_download_source: true)
      EmailBackupToken.del(current_user.id)
      StaffActionLogger.new(current_user).log_backup_download(backup)

      if store.remote?
        redirect_to backup.source
      else
        headers['Content-Length'] = File.size(backup.source).to_s
        send_file backup.source
      end
    else
      render body: nil, status: 404
    end
  end

  def destroy
    store = BackupRestore::BackupStore.create

    if backup = store.file(params.fetch(:id))
      StaffActionLogger.new(current_user).log_backup_destroy(backup)
      store.delete_file(backup.filename)
      render body: nil
    else
      render body: nil, status: 404
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
    SiteSetting.set_and_log(:disable_emails, 'yes', current_user)
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
    readonly_mode_key = Discourse::USER_READONLY_MODE_KEY

    if enable
      Discourse.enable_readonly_mode(readonly_mode_key)
    else
      Discourse.disable_readonly_mode(readonly_mode_key)
    end

    StaffActionLogger.new(current_user).log_change_readonly_mode(enable)

    render body: nil
  end

  def check_backup_chunk
    identifier = params.fetch(:resumableIdentifier)
    filename = params.fetch(:resumableFilename)
    chunk_number = params.fetch(:resumableChunkNumber)
    current_chunk_size = params.fetch(:resumableCurrentChunkSize).to_i

    # path to chunk file
    chunk = BackupRestore::LocalBackupStore.chunk_path(identifier, filename, chunk_number)
    # check chunk upload status
    status = HandleChunkUpload.check_chunk(chunk, current_chunk_size: current_chunk_size)

    render body: nil, status: status
  end

  def upload_backup_chunk
    filename = params.fetch(:resumableFilename)
    total_size = params.fetch(:resumableTotalSize).to_i

    return render status: 415, plain: I18n.t("backup.backup_file_should_be_tar_gz") unless valid_extension?(filename)
    return render status: 415, plain: I18n.t("backup.not_enough_space_on_disk") unless has_enough_space_on_disk?(total_size)
    return render status: 415, plain: I18n.t("backup.invalid_filename") unless valid_filename?(filename)

    file = params.fetch(:file)
    identifier = params.fetch(:resumableIdentifier)
    chunk_number = params.fetch(:resumableChunkNumber).to_i
    chunk_size = params.fetch(:resumableChunkSize).to_i
    current_chunk_size = params.fetch(:resumableCurrentChunkSize).to_i

    # path to chunk file
    chunk = BackupRestore::LocalBackupStore.chunk_path(identifier, filename, chunk_number)
    # upload chunk
    HandleChunkUpload.upload_chunk(chunk, file: file)

    uploaded_file_size = chunk_number * chunk_size
    # when all chunks are uploaded
    if uploaded_file_size + current_chunk_size >= total_size
      # merge all the chunks in a background thread
      Jobs.enqueue_in(5.seconds, :backup_chunks_merger, filename: filename, identifier: identifier, chunks: chunk_number)
    end

    render body: nil
  end

  def create_upload_url
    params.require(:filename)
    filename = params.fetch(:filename)

    return render_error("backup.backup_file_should_be_tar_gz") unless valid_extension?(filename)
    return render_error("backup.invalid_filename") unless valid_filename?(filename)

    store = BackupRestore::BackupStore.create

    begin
      upload_url = store.generate_upload_url(filename)
    rescue BackupRestore::BackupStore::BackupFileExists
      return render_error("backup.file_exists")
    end

    render json: success_json.merge(url: upload_url)
  end

  private

  def has_enough_space_on_disk?(size)
    `df -Pk #{Rails.root}/public/backups | awk 'NR==2 {print $4 * 1024;}'`.to_i > size
  end

  def ensure_backups_enabled
    raise Discourse::InvalidAccess.new unless SiteSetting.enable_backups?
  end

  def valid_extension?(filename)
    /\.(tar\.gz|t?gz)$/i =~ filename
  end

  def valid_filename?(filename)
    !!(/^[a-zA-Z0-9\._\-]+$/ =~ filename)
  end

  def render_error(message_key)
    render json: failed_json.merge(message: I18n.t(message_key))
  end
end
