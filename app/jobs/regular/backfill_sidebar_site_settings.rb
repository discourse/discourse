# frozen_string_literal: true

class Jobs::BackfillSidebarSiteSettings < Jobs::Base
  def execute(args)
    SidebarSiteSettingsBackfiller.new(
      args[:setting_name],
      previous_value: args[:previous_value],
      new_value: args[:new_value],
    ).backfill!
  end
end
