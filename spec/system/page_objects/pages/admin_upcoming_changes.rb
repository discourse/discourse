# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminUpcomingChanges < PageObjects::Pages::Base
      def visit
        page.visit("/admin/config/upcoming-changes")
      end

      def change_row(setting_name)
        PageObjects::Components::AdminUpcomingChangeRow.new(setting_name)
      end

      def has_change?(setting_name, description: nil)
        description ||= SiteSettings::LabelFormatter.description(setting_name)
        change_row(setting_name).has_text?(description)
        change_row(setting_name).has_text?(
          SiteSettings::LabelFormatter.humanized_name(setting_name),
        )
      end
    end
  end
end
