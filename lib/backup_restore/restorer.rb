# frozen_string_literal: true

require "colored2"

module BackupRestore
  RestoreDisabledError = Class.new(RuntimeError)
  FilenameMissingError = Class.new(RuntimeError)

  class Restorer
    delegate :log, to: :@logger, private: true

    attr_reader :success

    def initialize(
      user_id:,
      filename:,
      factory:,
      disable_emails: true,
      location: nil,
      interactive: false
    )
      @user_id = user_id
      @filename = filename
      @factory = factory
      @logger = factory.logger
      @disable_emails = disable_emails
      @interactive = interactive

      ensure_restore_is_enabled
      ensure_we_have_a_user
      ensure_we_have_a_filename

      @success = false
      @current_db = RailsMultisite::ConnectionManagement.current_db

      @system = factory.create_system_interface
      @backup_file_handler = factory.create_backup_file_handler(@filename, @current_db, location)
      @database_restorer = factory.create_database_restorer(@current_db)
      @uploads_restorer = factory.create_uploads_restorer
    end

    def run
      log "[STARTED]"
      log "'#{@user_info[:username]}' has started the restore!"

      # FIXME not atomic!
      ensure_no_operation_is_running
      @system.mark_restore_as_running

      @system.listen_for_shutdown_signal

      @tmp_directory, db_dump_path = @backup_file_handler.decompress
      validate_backup_metadata

      @system.enable_readonly_mode
      @system.pause_sidekiq("restore")
      @system.wait_for_sidekiq
      @system.flush_redis
      @system.clear_sidekiq_queues

      @database_restorer.restore(db_dump_path, @interactive)

      reload_site_settings

      @system.disable_readonly_mode

      clear_category_cache
      clear_stats
      reload_translations

      restore_uploads

      clear_emoji_cache
      clear_theme_cache

      after_restore_hook
    rescue Compression::Strategy::ExtractFailed
      log "ERROR: The uncompressed file is too big. Consider increasing the hidden " \
            '"decompressed_backup_max_file_size_mb" setting.'
      @database_restorer.rollback
    rescue SystemExit
      log "Restore process was cancelled!"
      @database_restorer.rollback
    rescue => ex
      log "EXCEPTION: " + ex.message
      log ex.backtrace.join("\n")
      @database_restorer.rollback
    else
      @success = true
    ensure
      clean_up
      notify_user
      log "Finished!"

      @success ? log("[SUCCESS]") : log("[FAILED]")
    end

    protected

    def ensure_restore_is_enabled
      return if Rails.env.development? || SiteSetting.allow_restore?
      raise BackupRestore::RestoreDisabledError
    end

    def ensure_no_operation_is_running
      raise BackupRestore::OperationRunningError if BackupRestore.is_operation_running?
    end

    def ensure_we_have_a_user
      user = User.find_by(id: @user_id)
      raise Discourse::InvalidParameters.new(:user_id) if user.blank?

      # keep some user data around to check them against the newly restored database
      @user_info = { id: user.id, username: user.username, email: user.email }
    end

    def ensure_we_have_a_filename
      raise BackupRestore::FilenameMissingError if @filename.nil?
    end

    def validate_backup_metadata
      @factory.create_meta_data_handler(@filename, @tmp_directory).validate
    end

    def reload_site_settings
      log "Reloading site settings..."
      SiteSetting.refresh!

      DiscourseEvent.trigger(:site_settings_restored)

      if @disable_emails && SiteSetting.disable_emails == "no"
        log "Disabling outgoing emails for non-staff users..."
        user = User.find_by_email(@user_info[:email]) || Discourse.system_user
        SiteSetting.set_and_log(:disable_emails, "non-staff", user)
      end
    end

    def clear_category_cache
      log "Clearing category cache..."
      Category.reset_topic_ids_cache
      Category.clear_subcategory_ids
    end

    def clear_emoji_cache
      log "Clearing emoji cache..."
      Emoji.clear_cache
    rescue => ex
      log "Something went wrong while clearing emoji cache.", ex
    end

    def reload_translations
      log "Reloading translations..."
      TranslationOverride.reload_all_overrides!
    end

    def restore_uploads
      if @interactive
        puts ""
        puts "Attention! Pausing restore before uploads.".red.bold
        puts "You can work on the restored database in a separate Rails console."
        puts ""
        puts "Press any key to continue with the restore.".bold
        puts ""
        STDIN.getch
      end

      @uploads_restorer.restore(@tmp_directory)
    end

    def notify_user
      return if @success && @user_id == Discourse::SYSTEM_USER_ID

      if user = User.find_by_email(@user_info[:email])
        log "Notifying '#{user.username}' of the end of the restore..."
        status = @success ? :restore_succeeded : :restore_failed

        logs = Discourse::Utils.logs_markdown(@logger.logs, user: user)
        post = SystemMessage.create_from_system_user(user, status, logs: logs)
      else
        log "Could not send notification to '#{@user_info[:username]}' " \
              "(#{@user_info[:email]}), because the user does not exist."
      end
    rescue => ex
      log "Something went wrong while notifying user.", ex
    end

    def clean_up
      log "Cleaning stuff up..."
      @database_restorer.clean_up
      @backup_file_handler.clean_up
      @system.unpause_sidekiq
      @system.disable_readonly_mode if Discourse.readonly_mode?
      @system.mark_restore_as_not_running
    end

    def clear_theme_cache
      log "Clear theme cache"
      ThemeField.force_recompilation!
      Theme.expire_site_cache!
      Stylesheet::Manager.cache.clear
    rescue => ex
      log "Something went wrong while clearing theme cache.", ex
    end

    def clear_stats
      Discourse.stats.remove("missing_s3_uploads")
    end

    def after_restore_hook
      log "Executing the after_restore_hook..."
      DiscourseEvent.trigger(:restore_complete)
    end
  end
end
