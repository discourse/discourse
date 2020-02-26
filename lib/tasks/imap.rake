# frozen_string_literal: true

task "imap:sync" => :environment do
  puts "Topic.count = #{Topic.count}\n"
  puts "Post.count = #{Post.count}\n"
  puts "IncomingEmail.count = #{IncomingEmail.count}\n"
  puts "\n"

  Group.where.not(imap_mailbox_name: '').each do |group|
    DistributedMutex.synchronize("imap_poll_#{group.id}") do
      puts "Syncing emails for group #{group.name} (#{group.id})...\n"
      imap_sync = Imap::Sync.for_group(group,
        import_limit: 0,
        old_emails_limit: 500,
        new_emails_limit: 200
      )

      begin
        loop do
          status = imap_sync.process
          print "#{status.remaining}... "
          break if status.remaining == 0
        end

        puts "DONE!\n"
      rescue Net::IMAP::Error => e
        puts "\nERROR: Could not connect to IMAP for group #{group.name}: #{e.message}\n"
      ensure
        imap_sync.disconnect!
      end
    end
  end

  puts "\n"
  puts "Topic.count = #{Topic.count}\n"
  puts "Post.count = #{Post.count}\n"
  puts "IncomingEmail.count = #{IncomingEmail.count}\n"
end
