# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminUpcomingChanges < PageObjects::Pages::Base
      def visit
        page.visit("/admin/config/upcoming-changes")
      end

      def change_item(setting_name)
        PageObjects::Components::AdminUpcomingChangeItem.new(setting_name)
      end

      def has_change?(setting_name, description: nil)
        description ||= SiteSettings::LabelFormatter.description(setting_name)
        change_item(setting_name).exists?
        change_item(setting_name).has_text?(description)
        change_item(setting_name).has_text?(
          SiteSettings::LabelFormatter.humanized_name(setting_name),
        )
      end

      def has_no_change?(setting_name)
        change_item(setting_name).does_not_exist?
      end

      def filter_controls
        PageObjects::Components::AdminFilterControls.new(
          ".upcoming-changes",
          has_multiple_dropdowns: true,
        )
      end
    end
  end
end
