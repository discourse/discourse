desc "This task is called by the Heroku scheduler add-on"

# Every day at 6am
task :enqueue_digest_emails => :environment do
  Jobs::EnqueueDigestEmails.new.execute(nil)
end

# Every day at 4am
task :category_stats => :environment do
  Jobs::CategoryStats.new.execute(nil)
end

# Every 10 minutes
task :periodical_updates => :environment do
  Jobs::PeriodicalUpdates.new.execute(nil)
end

# Every day
task :version_check => :environment do
  Jobs::VersionCheck.new.execute(nil)
end