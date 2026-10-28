# frozen_string_literal: true

require "mini_mime"
require "file_store/s3_store"

module BackupRestore
  class Creator
    attr_reader :success, :store

    def initialize(user_id, opts = {})
      @user_id = user_id
      @client_id = opts[:client_id]
      @publish_to_message_bus = opts[:publish_to_message_bus] || false
      @with_uploads = opts[:with_uploads] == false ? false : include_uploads?
      @filename_override = opts[:filename]
      @ticket = opts[:ticket]

      initialize_state
    end

    def run
      ensure_no_operation_is_running
      ensure_we_have_a_user

      log "[STARTED]"
      log "'#{@user.username}' has started the backup!"

      mark_backup_as_running

      listen_for_shutdown_signal

      ensure_directory_exists(@tmp_directory)
      ensure_directory_exists(@archive_directory)

      update_metadata
      dump_public_schema

      log "Finalizing backup..."

      @with_uploads ? create_archive : move_dump_backup
      upload_archive

      after_create_hook
    rescue SystemExit
      log "Backup process was cancelled!"
    rescue Exception => ex
      log "EXCEPTION: " + ex.message
      log ex.backtrace.join("\n")
    else
      @success = true
      @backup_filename
    ensure
      delete_old
      clean_up
      notify_user
      log "Finished!"
      publish_completion
    end

    def delete_prior_to_n_days
      return if Rails.env.development?
      store.delete_prior_to_n_days
    rescue => ex
      log "Something went wrong while deleting backups prior to n days....", ex
    end

    protected

    def ensure_no_operation_is_running
      raise BackupRestore::OperationRunningError if BackupRestore.is_operation_running?
    end

    def ensure_we_have_a_user
      raise Discourse::InvalidParameters.new(:user_id) unless @user
    end

    def get_parameterized_title
      SiteSetting.title.parameterize[...64].presence || "discourse"
    end

    def initialize_state
      @success = false
      @user = User.find_by(id: @user_id)
      @logs = []
      @store = BackupRestore::BackupStore.create
      @current_db = RailsMultisite::ConnectionManagement.current_db
      @timestamp = Time.now.strftime("%Y-%m-%d-%H%M%S")
      @tmp_directory = File.join(Rails.root, "tmp", "backups", @current_db, @timestamp)
      @dump_filename = File.join(@tmp_directory, BackupRestore::DUMP_FILE)
      @archive_directory = BackupRestore::LocalBackupStore.base_directory(db: @current_db)
      filename = @filename_override || "#{get_parameterized_title}-#{@timestamp}"
      @archive_basename =
        File.join(
          @archive_directory,
          "#{filename}-#{BackupRestore::VERSION_PREFIX}#{Discourse::VERSION::STRING.tr(".", "-")}-#{BackupRestore.current_database_version}",
        )

      @backup_filename =
        if @with_uploads
          "#{File.basename(@archive_basename)}.tar.gz"
        else
          "#{File.basename(@archive_basename)}.sql.gz"
        end
    end

    def listen_for_shutdown_signal
      BackupRestore.clear_shutdown_signal!

      Thread.new do
        Thread.current.name = "shutdown_wait"

        RailsMultisite::ConnectionManagement.with_connection(@current_db) do
          while BackupRestore.is_operation_running?
            exit if BackupRestore.should_shutdown?
            sleep 0.1
          end
        end
      end
    end

    def mark_backup_as_running
      log "Marking backup as running..."
      BackupRestore.mark_as_running!
    end

    def update_metadata
      log "Updating metadata..."
      BackupMetadata.delete_all
      BackupMetadata.create!(name: "base_url", value: Discourse.base_url)
      BackupMetadata.create!(name: "cdn_url", value: Discourse.asset_host)
      BackupMetadata.create!(
        name: "s3_base_url",
        value: SiteSetting.Upload.enable_s3_uploads ? SiteSetting.Upload.s3_base_url : nil,
      )
      BackupMetadata.create!(
        name: "s3_cdn_url",
        value: SiteSetting.Upload.enable_s3_uploads ? SiteSetting.Upload.s3_cdn_url : nil,
      )
      BackupMetadata.create!(
        name: "db_name",
        value: RailsMultisite::ConnectionManagement.current_db,
      )
      BackupMetadata.create!(name: "multisite", value: Rails.configuration.multisite)
    end

    def dump_public_schema
      log "Dumping the public schema of the database..."

      logs = Queue.new
      pg_dump_running = true

      Thread.new do
        RailsMultisite::ConnectionManagement.establish_connection(db: @current_db)
        while pg_dump_running
          message = logs.pop.strip
          log(message) if message.present?
        end
      end

      IO.popen("#{pg_dump_command} 2>&1") do |pipe|
        while line = pipe.readline
          logs << line
        end
      rescue EOFError
        # finished reading...
      ensure
        pg_dump_running = false
        logs << ""
      end

      raise "pg_dump failed" unless $?.success?
    end

    def pg_dump_command
      db_conf = BackupRestore.database_configuration

      password_argument = "PGPASSWORD='#{db_conf.password}'" if db_conf.password.present?
      host_argument = "--host=#{db_conf.host}" if db_conf.host.present?
      port_argument = "--port=#{db_conf.port}" if db_conf.port.present?
      username_argument = "--username=#{db_conf.username}" if db_conf.username.present?

      [
        password_argument, # pass the password to pg_dump (if any)
        "pg_dump", # the pg_dump command
        "--schema=public", # only public schema
        "-T public.pg_*", # exclude tables and views whose name starts with "pg_"
        "--exclude-table-data=public.nested_hot_post_scores",
        "--exclude-table-data=public.nested_hot_score_snapshots",
        "--file='#{@dump_filename}'", # output to the dump.sql file
        "--no-owner", # do not output commands to set ownership of objects
        "--no-privileges", # prevent dumping of access privileges
        "--verbose", # specifies verbose mode
        "--compress=4", # Compression level of 4
        host_argument, # the hostname to connect to (if any)
        port_argument, # the port to connect to (if any)
        username_argument, # the username to connect as (if any)
        db_conf.database, # the name of the database to dump
      ].join(" ")
    end

    def move_dump_backup
      log "Finalizing database dump file: #{@backup_filename}"

      archive_filename = File.join(@archive_directory, @backup_filename)

      FileUtils.mv(@dump_filename, archive_filename)

      remove_tmp_directory
    rescue SystemCallError => error
      raise "Failed to move database dump file.\n#{error.message}"
    end

    def create_archive
      log "Streaming archive through gzip: #{@backup_filename}"
      archive_path = "#{@archive_basename}.tar.gz"
      partial_path = "#{archive_path}.partial"
      @archive_mutex = Mutex.new

      File.open(partial_path, "wb") do |output|
        compress_archive(output) do |input|
          ArchiveWriter.write(input) do |archive|
            @archive = archive
            log "Archiving data dump..."
            @archive.add_file(@dump_filename, File.basename(@dump_filename))
            add_local_uploads_to_archive
            add_remote_uploads_to_archive if SiteSetting.Upload.enable_s3_uploads
          end
        end
      end

      File.rename(partial_path, archive_path)
      remove_tmp_directory
    ensure
      @archive = nil
      FileUtils.rm_f(partial_path) if partial_path
    end

    def compress_archive(output)
      Tempfile.create("backup-gzip-errors-", @tmp_directory) do |errors|
        begin
          IO.popen(
            ["gzip", "-#{SiteSetting.backup_gzip_compression_level_for_uploads}", "-c"],
            "wb",
            out: output,
            err: errors,
          ) { |input| yield input }
        rescue Errno::EPIPE => write_error
          # IO.popen waits for gzip before we read its error, including worker failures.
        end

        status = $?
        if write_error || !status.success?
          errors.rewind
          raise "Failed to gzip archive (exit status #{status.exitstatus}). #{errors.read.presence || write_error&.message}"
        end
      end
    end

    def add_path_to_archive(source, path, exclude: nil, ancestors: Set.new)
      return if path == exclude

      stat = File.stat(source)
      if stat.directory?
        inode = [stat.dev, stat.ino]
        raise "Directory cycle while archiving: #{source}" if ancestors.include?(inode)
        @archive.add_directory(path, source: source)
        ancestors.add(inode)
        begin
          Dir.each_child(source) do |name|
            add_path_to_archive(
              File.join(source, name),
              File.join(path, name),
              exclude: exclude,
              ancestors: ancestors,
            )
          end
        ensure
          ancestors.delete(inode)
        end
      elsif stat.file?
        @archive.add_file(source, path)
      end
    rescue Errno::ENOENT
      log "Skipping missing local upload: #{source}"
    end

    def include_uploads?
      has_local_uploads? || SiteSetting.include_s3_uploads_in_backups
    end

    def local_uploads_directory
      @local_uploads_directory ||= Rails.public_path.join(Discourse.store.upload_path).to_s
    end

    def has_local_uploads?
      File.directory?(local_uploads_directory) && !Dir.empty?(local_uploads_directory)
    end

    def add_local_uploads_to_archive
      log "Archiving uploads..."
      if has_local_uploads?
        exclude =
          File.join(
            Discourse.store.upload_path,
            "optimized",
          ) unless SiteSetting.include_thumbnails_in_backups
        add_path_to_archive(local_uploads_directory, Discourse.store.upload_path, exclude: exclude)
      else
        log "No local uploads found. Skipping archiving of local uploads..."
      end
    end

    # Lightweight immutable value object to avoid holding full ActiveRecord objects in memory
    # Includes extension and original_filename for FileStore::BaseStore#get_path_for_upload
    # fallback path when URL doesn't match UPLOAD_PATH_REGEX
    UploadData = Data.define(:id, :url, :sha1, :extension, :original_filename)

    def add_remote_uploads_to_archive
      if !SiteSetting.include_s3_uploads_in_backups
        log "Skipping uploads stored on S3."
        return
      end

      log "Downloading uploads from S3. This may take a while..."

      @s3_store = FileStore::S3Store.new
      @upload_directory = Discourse.store.upload_path
      @download_stats = { downloaded: 0, hardlinked: 0, copied: 0 }
      @stats_mutex = Mutex.new

      uploads_by_sha1 = group_remote_uploads_by_sha1
      @total_uploads = uploads_by_sha1.values.sum(&:size)
      log "Found #{uploads_by_sha1.size} unique files from #{@total_uploads} total uploads"

      download_upload_groups(uploads_by_sha1.values)

      log "Finished processing uploads: #{@download_stats[:downloaded]} downloaded, #{@download_stats[:hardlinked]} hardlinked, #{@download_stats[:copied]} copied"

      if @download_stats[:downloaded] == 0 && @download_stats[:hardlinked] == 0 &&
           @download_stats[:copied] == 0
        log "No uploads found on S3. Skipping archiving of uploads stored on S3..."
      end
    end

    def download_upload_groups(upload_groups)
      concurrency = [GlobalSetting.backup_s3_download_concurrency.to_i, 1].max
      log "Downloading upload groups with #{concurrency} worker(s)"

      if concurrency == 1
        upload_groups.each { |group| process_upload_group(group) }
        return
      end

      return if upload_groups.empty?

      concurrency = [concurrency, upload_groups.size].min

      # Initialize the shared client and bucket in the originating site's context.
      @s3_store.s3_helper.object("")
      queue = Queue.new
      upload_groups.each { |group| queue << group }
      queue.close
      workers = []
      errors = Queue.new

      begin
        # Defer cancellation until every started worker has been registered.
        Thread.handle_interrupt(Exception => :never) do
          concurrency.times do
            workers << Thread.new do
              Thread.handle_interrupt(Exception => :immediate) do
                RailsMultisite::ConnectionManagement.with_connection(@current_db) do
                  while (group = queue.pop)
                    process_upload_group(group)
                  end
                end
              end
            rescue Exception => error
              # Propagate worker failures on the backup thread after workers finish.
              queue.clear
              errors << error
            ensure
              ActiveRecord::Base.connection_handler.clear_active_connections!
            end
          end
        end
        workers.each(&:join)
        raise errors.pop unless errors.empty?
      ensure
        # Finish active downloads, but leave queued groups untouched on cancellation.
        queue.clear
        workers.each(&:join)
      end
    end

    def group_remote_uploads_by_sha1
      # Filter remote uploads at DB level and pluck only needed fields
      # Local uploads have URLs like "/uploads/..." but NOT protocol-relative "//"
      upload_tuples =
        Upload.where("url NOT LIKE '/%' OR url LIKE '//%'").pluck(
          Arel.sql("COALESCE(NULLIF(original_sha1, ''), sha1)"),
          :id,
          :url,
          :sha1,
          :extension,
          :original_filename,
        )

      uploads_by_sha1 = {}
      upload_tuples.each do |sha1_key, id, url, sha1, extension, original_filename|
        uploads_by_sha1[sha1_key] ||= []
        uploads_by_sha1[sha1_key] << UploadData.new(
          id:,
          url:,
          sha1:,
          extension:,
          original_filename:,
        )
      end
      uploads_by_sha1
    end

    def process_upload_group(upload_group)
      primary = upload_group.first
      # Each worker stages one file, then waits for the writer before downloading another.
      Tempfile.create(%w[backup-upload- .tmp], @tmp_directory) do |file|
        file.close
        next unless download_upload_to_file(primary, file.path)

        @archive_mutex.synchronize do
          primary_path = upload_path_in_archive(primary)
          @archive.add_file(file.path, primary_path, mode: 0o644)
          archived_paths = Set.new([primary_path])
          link_count = 1
          upload_group
            .drop(1)
            .each do |duplicate|
              path = upload_path_in_archive(duplicate)
              next unless archived_paths.add?(path)
              if link_count >= ArchiveWriter::MAX_LINKS
                @archive.add_file(file.path, path, mode: 0o644)
                primary_path = path
                link_count = 1
                increment_and_log_progress(:copied)
              else
                @archive.add_hardlink(path, primary_path)
                link_count += 1
                increment_and_log_progress(:hardlinked)
              end
            end
        end
      end
    end

    def upload_path_in_archive(upload_data)
      File.join(@upload_directory, @s3_store.get_path_for_upload(upload_data))
    end

    def download_upload_to_file(upload_data, filename)
      FileUtils.mkdir_p(File.dirname(filename))
      # Avoid a HEAD request for every file; backup workers already parallelize downloads.
      @s3_store.download_file(upload_data, filename, mode: "single_request")
      increment_and_log_progress(:downloaded)
      true
    rescue StandardError => ex
      log "Failed to download file with upload ID #{upload_data.id} from S3", ex
      false
    end

    def increment_and_log_progress(type)
      @stats_mutex.synchronize do
        @download_stats[type] += 1
        processed = @download_stats.values.sum
        return if processed % 1000 != 0

        percentage = processed * 100 / @total_uploads
        log "#{processed}/#{@total_uploads} (#{percentage}%) files processed (#{@download_stats[:downloaded]} downloaded, #{@download_stats[:hardlinked]} hardlinked, #{@download_stats[:copied]} copied). Still processing..."
      end
    end

    def upload_archive
      return unless store.remote?

      log "Uploading archive..."
      content_type =
        MiniMime.lookup_by_filename(@backup_filename)&.content_type || "application/gzip"
      archive_path = File.join(@archive_directory, @backup_filename)
      store.upload_file(@backup_filename, archive_path, content_type)
    end

    def after_create_hook
      log "Executing the after_create_hook for the backup..."
      DiscourseEvent.trigger(:backup_created)
    end

    def delete_old
      return if Rails.env.development?

      log "Deleting old backups..."
      store.delete_old
    rescue => ex
      log "Something went wrong while deleting old backups.", ex
    end

    def notify_user
      return if success && @user.id == Discourse::SYSTEM_USER_ID

      log "Notifying '#{@user.username}' of the end of the backup..."
      status = success ? :backup_succeeded : :backup_failed

      logs = Discourse::Utils.logs_markdown(@logs, user: @user)
      post = SystemMessage.create_from_system_user(@user, status, logs: logs)

      post.topic.invite_group(@user, Group[:admins]) if @user.id == Discourse::SYSTEM_USER_ID
    rescue => ex
      log "Something went wrong while notifying user.", ex
    end

    def clean_up
      log "Cleaning stuff up..."
      delete_uploaded_archive
      remove_tar_leftovers
      mark_backup_as_not_running
      refresh_disk_space if success
    end

    def delete_uploaded_archive
      return unless store.remote?

      archive_path = File.join(@archive_directory, @backup_filename)

      if File.exist?(archive_path)
        log "Removing archive from local storage..."
        File.delete(archive_path)
      end
    rescue => ex
      log "Something went wrong while deleting uploaded archive from local storage.", ex
    end

    def refresh_disk_space
      log "Refreshing disk stats..."
      store.reset_cache
    rescue => ex
      log "Something went wrong while refreshing disk stats.", ex
    end

    def remove_tar_leftovers
      log "Removing unfinished archive leftovers..."
      Dir["#{@archive_directory}/*.{tar,tar.gz.partial}"].each { |filename| File.delete(filename) }
    rescue => ex
      log "Something went wrong while removing unfinished archive leftovers.", ex
    end

    def remove_tmp_directory
      log "Removing tmp '#{@tmp_directory}' directory..."
      FileUtils.rm_rf(@tmp_directory) if Dir[@tmp_directory].present?
    rescue => ex
      log "Something went wrong while removing the following tmp directory: #{@tmp_directory}", ex
    end

    def mark_backup_as_not_running
      log "Marking backup as finished..."
      BackupRestore.mark_as_not_running!
    rescue => ex
      log "Something went wrong while marking backup as finished.", ex
    end

    def ensure_directory_exists(directory)
      log "Making sure '#{directory}' exists..."
      FileUtils.mkdir_p(directory)
    end

    def log(message, ex = nil)
      timestamp = Time.now.strftime("%Y-%m-%d %H:%M:%S")
      puts(message) if !Rails.env.test?
      publish_log(message, timestamp)
      save_log(message, timestamp)
      Rails.logger.error("#{ex}\n" + ex.backtrace.join("\n")) if ex
    end

    def publish_log(message, timestamp)
      return unless @publish_to_message_bus
      data = { timestamp: timestamp, operation: "backup", message: message }
      MessageBus.publish(
        BackupRestore::LOGS_CHANNEL,
        data,
        user_ids: [@user_id],
        client_ids: [@client_id],
      )
    end

    def save_log(message, timestamp)
      @logs << "[#{timestamp}] #{message}"
    end

    def publish_completion
      if success
        log("[SUCCESS]")
        DiscourseEvent.trigger(:backup_complete, logs: @logs, ticket: @ticket)
      else
        log("[FAILED]")
        DiscourseEvent.trigger(:backup_failed, logs: @logs, ticket: @ticket)
      end
    end
  end

  # Backwards compatibility alias for plugins referencing the old name
  Backuper = Creator
end
