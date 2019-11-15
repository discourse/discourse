# frozen_string_literal: true

require 'benchmark'

desc "This task is called by the Heroku scheduler add-on"

task enqueue_digest_emails: :environment do
  Jobs::EnqueueDigestEmails.new.execute(nil)
end

task category_stats: :environment do
  Jobs::CategoryStats.new.execute(nil)
end

task periodical_updates: :environment do
  Jobs::PeriodicalUpdates.new.execute(nil)
end

task version_check: :environment do
  Jobs::VersionCheck.new.execute(nil)
end

desc "run every task the scheduler knows about in that order, use only for debugging"
task 'scheduler:run_all' => :environment do
  MiniScheduler::Manager.discover_schedules.each do |schedule|
    puts "Running #{schedule}"
    elapsed = Benchmark.realtime { schedule.new.execute({}) }
    puts "Elapsed #{(elapsed * 1000).to_i}ms"
  end
end
