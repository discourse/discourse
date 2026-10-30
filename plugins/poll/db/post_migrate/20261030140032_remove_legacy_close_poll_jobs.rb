# frozen_string_literal: true

class RemoveLegacyClosePollJobs < ActiveRecord::Migration[8.1]
  def up
    site = RailsMultisite::ConnectionManagement.current_db

    Sidekiq::ScheduledSet
      .new
      .scan("Jobs::ClosePoll") do |job|
        next if job.klass != "Jobs::ClosePoll"

        args = job.args.first
        job.delete if args["current_site_id"] == site && !args.key?("poll_id")
      end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
