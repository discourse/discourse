# frozen_string_literal: true

task "imap:sync" => :environment do
  Group.where.not(imap_mailbox_name: '').each do |group|
    DistributedMutex.synchronize("imap_poll_#{group.id}") do
      puts "Syncing emails for group #{group.name} (#{group.id})..."
      imap_sync = Imap::Sync.for_group(group,
        import_limit: 0,
        old_emails_limit: 500,
        new_emails_limit: 200
      )

      begin
        loop do
          new_emails_count = imap_sync.process
          print "#{new_emails_count}... "
          break if new_emails_count == 0
        end

        puts "DONE!"
      rescue Net::IMAP::Error => e
        puts "ERROR: Could not connect to IMAP for group #{group.name}: #{e.message}"
      ensure
        imap_sync.disconnect!
      end
    end
  end
end
