# frozen_string_literal: true

module BackupRestore
  class RunningSidekiqJobsError < RuntimeError
    def initialize
      super("Sidekiq did not finish running all the jobs in the allowed time!")
    end
  end

  class SystemInterface
    delegate :log, to: :@logger, private: true

    def initialize(logger)
      @logger = logger

      @current_db = RailsMultisite::ConnectionManagement.current_db
      @readonly_mode_was_enabled = Discourse.readonly_mode?
    end

    def enable_readonly_mode
      return if @readonly_mode_was_enabled
      log "Enabling readonly mode..."
      Discourse.enable_readonly_mode
    end

    def disable_readonly_mode
      return if @readonly_mode_was_enabled
      log "Disabling readonly mode..."
      Discourse.disable_readonly_mode
    rescue => ex
      log "Something went wrong while disabling readonly mode.", ex
    end

    def mark_restore_as_running
      log "Marking restore as running..."
      BackupRestore.mark_as_running!
    end

    def mark_restore_as_not_running
      log "Marking restore as finished..."
      BackupRestore.mark_as_not_running!
    rescue => ex
      log "Something went wrong while marking restore as finished.", ex
    end

    def listen_for_shutdown_signal
      Thread.new do
        while BackupRestore.is_operation_running?
          exit if BackupRestore.should_shutdown?
          sleep 0.1
        end
      end
    end

    def pause_sidekiq
      log "Pausing sidekiq..."
      Sidekiq.pause!
    end

    def unpause_sidekiq
      log "Unpausing sidekiq..."
      Sidekiq.unpause!
    rescue => ex
      log "Something went wrong while unpausing Sidekiq.", ex
    end

    def wait_for_sidekiq
      # Wait at least 6 seconds because the data about workers is updated every 5 seconds
      # https://github.com/mperham/sidekiq/wiki/API#workers
      max_wait_seconds = 60
      wait_seconds = 6.0

      log "Waiting up to #{max_wait_seconds} seconds for Sidekiq to finish running jobs..."

      max_iterations = (max_wait_seconds / wait_seconds).ceil
      iterations = 1

      loop do
        sleep wait_seconds
        break if !sidekiq_has_running_jobs?

        iterations += 1
        raise RunningSidekiqJobsError.new if iterations > max_iterations

        log "Waiting for sidekiq to finish running jobs... ##{iterations}"
      end
    end

    protected

    def sidekiq_has_running_jobs?
      Sidekiq::Workers.new.each do |_, _, work|
        args = work&.dig("payload", "args")&.first
        current_site_id = args["current_site_id"] if args.present?

        return true if current_site_id.blank? || current_site_id == @current_db
      end

      false
    end
  end
end
