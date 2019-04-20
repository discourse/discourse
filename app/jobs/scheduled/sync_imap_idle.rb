require_dependency 'imap'

module Jobs
  class SyncImapIdle < Jobs::Scheduled
    queue :imap_idle
    every 5.seconds

    def execute(args)
      @args = args
      @threads = {}

      loop do
        @threads.filter! do |mailbox_id, thread|
          if thread.status
            true
          else
            thread.join
            false
          end
        end

        Mailbox.where(sync: true).includes(:group).each do |mailbox|
          @threads[mailbox.id] ||= Thread.new do
            Rails.logger.info("Starting IMAP IDLE thread for #{mailbox.group.name}/#{mailbox.name}.")
            imap_sync = Imap::Sync.for_group(mailbox.group)

            loop do
              break if !mailbox.reload.sync
              imap_sync.process(mailbox, true)
            end

            imap_sync.disconnect!
          end
        end

        sleep 5
      end
    end
  end
end
