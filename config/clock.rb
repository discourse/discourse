require 'clockwork'
unless ENV['EMBED_CLOCKWORK']
  require_relative 'boot'
  require_relative 'environment'
end

# These are jobs you should run on a regular basis to make your
# forum work properly.

def setup_log
  Clockwork.configure do |config|
    config[:logger].close
    config[:logger] = Logger.new(ENV["CLOCK_LOG"])
  end if ENV["CLOCK_LOG"]
end

trap('HUP') { setup_log }
setup_log

module Clockwork
  handler do |job|
    # TODO: we need to rethink scheduling here, cancel scheduled jobs
    #  iterates through all jobs, that is massively inefficient
    # Jobs.cancel_scheduled_job(job, all_sites: true)
    #
    # see: http://meta.discourse.org/t/auto-close-behaviour/8249/2
    Jobs.enqueue(job, all_sites: true)
  end

  every(1.day, 'enqueue_digest_emails', at: '06:00')
  every(1.day, 'category_stats', at: '04:00')
  every(1.day, 'ensure_db_consistency', at: '02:00')
  every(10.minutes, 'periodical_updates')
  every(1.day, 'version_check')
  every(1.minute, 'clockwork_heartbeat')
  every(1.minute, 'poll_mailbox')
  every(2.hours, 'destroy_old_deletion_stubs')

end
