# frozen_string_literal: true

desc "Backfill browser pageview daily rollups for a given date range"
task "browser_pageview_rollups:backfill", %i[start_date end_date] => :environment do |_, args|
  start_date =
    if args[:start_date].present?
      Date.parse(args[:start_date])
    else
      BrowserPageviewEvent.minimum(:created_at)&.to_date
    end

  end_date = args[:end_date].present? ? Date.parse(args[:end_date]) : Date.current

  if start_date.nil?
    puts "No browser_pageview_events found and no start_date provided. Nothing to backfill."
    next
  end

  current = start_date
  while current <= end_date
    chunk_end = [current.end_of_month, end_date].min
    puts "Backfilling rollups from #{current} to #{chunk_end}..."

    DistributedMutex.synchronize(
      Jobs::AggregateBrowserPageviewDailyRollups::LOCK_KEY,
      validity: 2.hours,
    ) do
      BrowserPageviewCountryDailyRollup.aggregate(start_date: current, end_date: chunk_end)
      BrowserPageviewReferrerDailyRollup.aggregate(start_date: current, end_date: chunk_end)
    end

    current = chunk_end + 1
  end

  puts "Done."
end
