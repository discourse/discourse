require_dependency 'imap'

module Jobs
  class PollImap < Jobs::Scheduled
    every SiteSetting.imap_polling_period_mins.minutes
    sidekiq_options retry: false

    def execute(args)
      @args = args

      Group.all.each do |group|
        mailboxes = group.mailboxes.where(sync: true)
        next if mailboxes.empty?

        imap_sync = Imap::Sync.for_group(group)

        begin
          mailboxes.each { |mailbox| imap_sync.process(mailbox) }
        rescue Net::IMAP::Error => e
          Rails.logger.warn("Could not connect to IMAP for group #{group.name}: #{e.message}")
        ensure
          imap_sync.disconnect!
        end
      end

      nil
    end
  end
end
