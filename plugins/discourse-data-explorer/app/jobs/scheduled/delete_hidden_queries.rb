# frozen_string_literal: true

module Jobs
  class DeleteHiddenQueries < ::Jobs::Scheduled
    every 7.days

    def execute(args)
      return unless SiteSetting.data_explorer_enabled

      DiscourseDataExplorer::Query
        .where("id > 0")
        .where(hidden: true)
        .where(
          "(last_run_at IS NULL OR last_run_at < :days_ago) AND updated_at < :days_ago",
          days_ago: 7.days.ago,
        )
        .delete_all
    end
  end
end
