# frozen_string_literal: true

require "demon/base"

class Demon::EmailSync < ::Demon::Base
  HEARTBEAT_KEY = "email_sync_heartbeat"
  HEARTBEAT_INTERVAL = 60.seconds

  def self.prefix
    "email_sync"
  end

  private

  def suppress_stdout
    false
  end

  def suppress_stderr
    false
  end

  def start_thread(db, group)
    Thread.new do
      RailsMultisite::ConnectionManagement.with_connection(db) do
        ImapSyncLog.debug("Thread started for group #{group.name} in db #{db}", group, db: false)
        begin
          syncer = Imap::Sync.new(group)
        rescue Net::IMAP::NoResponseError => e
          group.update(imap_last_error: e.message)
          Thread.exit
        end

        @sync_lock.synchronize { @sync_data[db][group.id][:syncer] = syncer }

        status = nil
        idle = false

        while @running && group.reload.imap_mailbox_name.present?
          ImapSyncLog.debug("Processing mailbox for group #{group.name} in db #{db}", group)
          status =
            syncer.process(
              idle: syncer.can_idle? && status && status[:remaining] == 0,
              old_emails_limit: status && status[:remaining] > 0 ? 0 : nil,
            )

          if !syncer.can_idle? && status[:remaining] == 0
            ImapSyncLog.debug(
              "Going to sleep for group #{group.name} in db #{db} to wait for new emails",
              group,
              db: false,
            )

            # Thread goes into sleep for a bit so it is better to return any
            # connection back to the pool.
            ActiveRecord::Base.connection_handler.clear_active_connections!

            sleep SiteSetting.imap_polling_period_mins.minutes
          end
        end

        syncer.disconnect!
      end
    end
  end

  def kill_threads
    # This is not really safe so the caller should ensure it happens in a
    # thread-safe context.
    # It should be safe when called from within a `trap` (there are no
    # synchronization primitives available anyway).
    @running = false

    @sync_data.each { |db, sync_data| sync_data.each { |_, data| kill_and_disconnect!(data) } }

    exit 0
  end

  def after_fork
    log("[EmailSync] Loading EmailSync in process id #{Process.pid}")

    loop do
      break if Discourse.redis.set(HEARTBEAT_KEY, Time.now.to_i, ex: HEARTBEAT_INTERVAL, nx: true)
      sleep HEARTBEAT_INTERVAL
    end

    log("[EmailSync] Starting EmailSync main thread")

    @running = true
    @sync_data = {}
    @sync_lock = Mutex.new

    trap("INT") { kill_threads }
    trap("TERM") { kill_threads }
    trap("HUP") { kill_threads }

    while @running
      Discourse.redis.set(HEARTBEAT_KEY, Time.now.to_i, ex: HEARTBEAT_INTERVAL)

      # Kill all threads for databases that no longer exist
      all_dbs = Set.new(RailsMultisite::ConnectionManagement.all_dbs)
      @sync_data.filter! do |db, sync_data|
        next true if all_dbs.include?(db)

        sync_data.each { |_, data| kill_and_disconnect!(data) }

        false
      end

      RailsMultisite::ConnectionManagement.each_connection do |db|
        next if !SiteSetting.enable_imap

        groups = Group.with_imap_configured.map { |group| [group.id, group] }.to_h

        @sync_lock.synchronize do
          @sync_data[db] ||= {}

          # Kill threads for group's mailbox that are no longer synchronized.
          @sync_data[db].filter! do |group_id, data|
            next true if groups[group_id] && data[:thread]&.alive? && !data[:syncer]&.disconnected?

            if !groups[group_id]
              ImapSyncLog.warn(
                "Killing thread for group because mailbox is no longer synced",
                group_id,
              )
            else
              ImapSyncLog.warn("Thread for group is dead", group_id)
            end

            kill_and_disconnect!(data)
            false
          end

          # Spawn new threads for groups that are now synchronized.
          groups.each do |group_id, group|
            if !@sync_data[db][group_id]
              ImapSyncLog.debug(
                "Starting thread for group #{group.name} mailbox #{group.imap_mailbox_name}",
                group,
                db: false,
              )

              @sync_data[db][group_id] = { thread: start_thread(db, group), syncer: nil }
            end
          end
        end
      end

      # Thread goes into sleep for a bit so it is better to return any
      # connection back to the pool.
      ActiveRecord::Base.connection_handler.clear_active_connections!

      sleep 5
    end

    @sync_lock.synchronize { kill_threads }
    Discourse.redis.del(HEARTBEAT_KEY)
    exit 0
  rescue => e
    log("#{e.message}: #{e.backtrace.join("\n")}")
    exit 1
  end

  def kill_and_disconnect!(data)
    data[:thread].kill
    data[:thread].join

    begin
      data[:syncer]&.disconnect!
    rescue Net::IMAP::ResponseError => err
      log(
        "[EmailSync] Encountered a response error when disconnecting: #{err}\n#{err.backtrace.join("\n")}",
      )
    end
  end
end
