# frozen_string_literal: true

require "demon/base"

class Demon::EmailSync < ::Demon::Base
  HEARTBEAT_KEY ||= "email_sync_heartbeat"
  HEARTBEAT_INTERVAL ||= 60.seconds

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

  def start_thread(group)
    Thread.new do
      begin
        obj = Imap::Sync.for_group(group)
      rescue Net::IMAP::NoResponseError => e
        puts("[EmailSync] Invalid credentials for #{group.name}")
        Thread.exit
      end

      @sync_lock.synchronize { @sync_data[group.id][:obj] = obj }

      status = nil
      idle = false

      while @running && group.reload.imap_mailbox_name.present? do
        status = obj.process(
          idle: obj.can_idle? && status && status[:remaining] == 0,
          old_emails_limit: status && status[:remaining] > 0 ? 0 : nil,
        )

        if !obj.can_idle? && status[:remaining] == 0
          # Thread goes into sleep for a bit so it is better to return any
          # connection back to the pool.
          ActiveRecord::Base.connection_handler.clear_active_connections!

          sleep SiteSetting.imap_polling_period_mins.minutes
        end
      end

      obj.disconnect!
    end
  end

  def kill_threads
    # This is not really safe so the caller should ensure it happens in a
    # thread-safe context.
    # It should be safe when called from within a `trap` (there are no
    # synchronization primitives available anyway).
    @running = false

    @sync_data.filter! do |_, sync|
      sync[:thread].kill
      sync[:thread].join
      sync[:obj]&.disconnect! rescue nil
    end

    exit 0
  end

  def after_fork
    puts "Loading EmailSync in process id #{Process.pid}"

    @running = true
    @sync_data = {}
    @sync_lock = Mutex.new

    trap('INT')  { kill_threads }
    trap('TERM') { kill_threads }
    trap('HUP')  { kill_threads }

    while @running
      Discourse.redis.set(HEARTBEAT_KEY, Time.now.to_i, ex: HEARTBEAT_INTERVAL)

      if SiteSetting.enable_imap
        groups = Group.where.not(imap_mailbox_name: '').map { |group| [group.id, group] }.to_h

        @sync_lock.synchronize do
          # Kill threads for group's mailbox that are no longer synchronized.
          @sync_data.filter! do |group_id, data|
            next true if groups[group_id] && data[:thread]&.alive?

            if !groups[group_id]
              puts("[EmailSync] Killing thread for group #{groups[group_id].name} because mailbox is no longer synced")
            else
              puts("[EmailSync] Thread for group #{groups[group_id].name} is dead")
            end

            data[:thread].kill
            data[:thread].join
            data[:obj]&.disconnect!

            false
          end

          # Spawn new threads for groups that are now synchronized.
          groups.each do |id, group|
            if !@sync_data[id]
              puts("[EmailSync] Starting thread for group #{group.name} and mailbox #{group.imap_mailbox_name}")
              @sync_data[id] = { thread: start_thread(group) }
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
  rescue => e
    STDERR.puts e.message
    STDERR.puts e.backtrace.join("\n")
    exit 1
  end
end
