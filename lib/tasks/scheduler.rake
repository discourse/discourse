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
task :calculate_avg_time => :environment do
  Jobs::CalculateAvgTime.new.execute(nil)
end

# Every 10 minutes
task :feature_topics => :environment do
  Jobs::FeatureTopics.new.execute(nil)
end

# Every 10 minutes
task :calculate_score => :environment do
  Jobs::CalculateScore.new.execute(nil)
end

# Every 10 minutes
task :calculate_view_counts => :environment do
  Jobs::CalculateViewCounts.new.execute(nil)
end

# Every day
task :version_check => :environment do
  Jobs::VersionCheck.new.execute(nil)
end