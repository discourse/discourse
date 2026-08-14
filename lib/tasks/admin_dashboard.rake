# frozen_string_literal: true

def each_dashboard_db(&block)
  if ENV["RAILS_DB"]
    block.call
  else
    RailsMultisite::ConnectionManagement.each_connection(&block)
  end
end

desc "Rebuild admin dashboard rollup tables. Pass a name to rebuild just one."
task "admin_dashboard:rebuild_rollups", [:name] => :environment do |_, args|
  name = args[:name].presence

  if name && !DashboardRollupRebuilder.known?(name)
    abort "Unknown rollup '#{name}'. Known rollups: #{DashboardRollupRebuilder.names.join(", ")}"
  end

  each_dashboard_db { DashboardRollupRebuilder.rebuild!(name) }
end

desc "Classify existing search logs as crawler traffic, for sites enabling crawler detection"
task "admin_dashboard:backfill_search_log_crawlers" => :environment do
  each_dashboard_db do
    db = RailsMultisite::ConnectionManagement.current_db
    flagged = SearchLog.backfill_likely_crawler!
    puts "#{db}: flagged #{flagged} search logs from known crawler user agents"

    next if !CrawlerScorer.enabled?

    window_start = BrowserPageviewEvent.retention_cutoff
    correlated =
      CrawlerScorer.flag_search_logs!(window_start: window_start, window_end: Time.zone.now)
    puts "#{db}: flagged #{correlated} more by correlating with scored pageviews"
  end
end
