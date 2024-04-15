# frozen_string_literal: true

class Jobs::BackfillSidebarSiteSettings < Jobs::Base
  # There should only be one of these jobs running at a time and it will be ordered based on the order in which the job
  # was enqueued.
  cluster_concurrency 1

  def execute(args)
    SidebarSiteSettingsBackfiller.new(
      args[:setting_name],
      previous_value: args[:previous_value],
      new_value: args[:new_value],
    ).backfill!
  end
end
