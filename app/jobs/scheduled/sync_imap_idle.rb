# frozen_string_literal: true

require_dependency 'imap/sync'

module Jobs
  class SyncImapIdle < ::Jobs::Scheduled
    LOCK_KEY ||= 'sync_imap_idle'

    every 30.seconds
    queue :imap_idle

    def execute(args)
      return if !SiteSetting.enable_imap || !SiteSetting.enable_imap_idle || !Discourse.redis.set(LOCK_KEY, 1, ex: 60.seconds, nx: true)

      @running = true
      @sync_data = {}
      @sync_lock = Mutex.new

      trap('INT')  { kill_threads }
      trap('TERM') { kill_threads }
      trap('HUP')  { kill_threads }

      # Ensure there is always one thread for each synced group mailbox.
      while @running
        Discourse.redis.set(LOCK_KEY, 1, ex: 60.seconds)
        groups = Group.where.not(imap_mailbox_name: '').map { |group| [group.id, group] }.to_h

        @sync_lock.synchronize do
          # Kill threads for group's mailbox that are no longer synchronized.
          @sync_data.filter! do |group_id, data|
            next true if groups[group_id] && data[:thread]&.alive?

            if !groups[group_id]
              Rails.logger.info("[IMAP] Killing thread for #{groups[group_id].name} (#{group_id}) because group's mailbox is no longer synced.")
            else
              Rails.logger.warn("[IMAP] Thread for #{groups[group_id].name} (#{group_id}) is dead.")
            end

            data[:thread].kill
            data[:thread].join
            data[:obj]&.disconnect!

            false
          end

          # Spawn new threads for groups that are now synchronized.
          groups.each do |id, group|
            if !@sync_data[id]
              Rails.logger.info("[IMAP] Starting IMAP IDLE thread for #{group.name} (#{group.id}) / #{group.imap_mailbox_name}.")
              @sync_data[id] = { thread: start_thread(group) }
            end
          end
        end

        # Thread goes into sleep for a bit so it is better to return any
        # connection back to the pool.
        ActiveRecord::Base.connection_handler.clear_active_connections!

        sleep 5
      end

      @sync_lock.synchronize { kill_threads }
    end

    def start_thread(group)
      Thread.new do
        obj = Imap::Sync.for_group(group)
        @sync_lock.synchronize { @sync_data[group.id][:obj] = obj }
        while @running && group.reload.imap_mailbox_name.present? do
          obj.process(idle: true)
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
    end
  end
end
