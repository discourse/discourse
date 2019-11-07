
# frozen_string_literal: true

require_dependency 'imap/sync'

module Jobs
  class SyncImapIdle < ::Jobs::Scheduled
    LOCK_KEY ||= 'sync_imap_idle'

    every 30.seconds
    queue :imap_idle

    def execute(args)
      return if !SiteSetting.enable_imap || !SiteSetting.enable_imap_idle || !$redis.set(LOCK_KEY, 1, ex: 60.seconds, nx: true)

      @running = true
      @syncs = {}
      @syncs_lock = Mutex.new

      trap('INT')  { kill_threads }
      trap('TERM') { kill_threads }
      trap('HUP')  { kill_threads }

      # Manage threads such that there is always one thread for each synced
      # group mailbox.
      while @running
        $redis.set(LOCK_KEY, 1, ex: 60.seconds)
        groups = Group.where.not(imap_mailbox_name: '').map { |m| [m.id, m] }.to_h

        @syncs_lock.synchronize do
          # Kill threads for group's mailbox that are no longer synchronized.
          @syncs.filter! do |id, sync|
            next true if groups[id] && sync[:thread]&.alive?

            if !groups[id]
              Rails.logger.info("[IMAP] Killing thread for #{groups[id].name} (#{id}) because group's mailbox is no longer synced.")
            else
              Rails.logger.warn("[IMAP] Thread for #{groups[id].name} (#{id}) is dead.")
            end

            sync[:thread].kill
            sync[:thread].join
            sync[:obj]&.disconnect!

            false
          end

          # Spawn new threads for groups that are now synchronized.
          groups.each do |id, group|
            if !@syncs[id]
              Rails.logger.info("[IMAP] Starting IMAP IDLE thread for #{group.name} (#{group.id}) / #{group.imap_mailbox_name}.")
              @syncs[id] = { thread: start_thread(group) }
            end
          end
        end

        ActiveRecord::Base.connection_handler.clear_active_connections!
        sleep 5
      end

      @syncs_lock.synchronize { kill_threads }
    end

    def start_thread(group)
      Thread.new do
        obj = Imap::Sync.for_group(group)
        @syncs_lock.synchronize { @syncs[group.id][:obj] = obj }
        while @running && group.reload.imap_mailbox_name.present? do
          ActiveRecord::Base.connection_handler.clear_active_connections!
          obj.process(true)
        end
        obj.disconnect!
      end
    end

    def kill_threads
      # This is not really safe, but it is called from within a `trap`
      # so it should be safe (also, there is no way to call any
      # synchronization primitives).
      @running = false
      @syncs.filter! do |_, sync|
        sync[:thread].kill
        sync[:thread].join
        sync[:obj]&.disconnect! rescue nil
      end
    end
  end
end
