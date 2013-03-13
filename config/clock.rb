require 'clockwork'
require_relative 'boot'
require_relative 'environment'

# These are jobs you should run on a regular basis to make your
# forum work properly.

module Clockwork
  handler do |job|
    Jobs.enqueue(job, all_sites: true)
  end

  every(1.day, 'enqueue_digest_emails', at: '06:00')
  every(1.day, 'category_stats', at: '04:00')
  every(10.minutes, 'calculate_avg_time')
  every(10.minutes, 'feature_topics')
  every(1.minute, 'calculate_score')
  every(20.minutes, 'calculate_view_counts')
  every(1.day, 'version_check')
end
