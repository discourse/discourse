# frozen_string_literal: true

module PageObjects
  module Components
    class AdminUpcomingChangeRow < PageObjects::Components::Base
      def initialize(setting_name)
        @setting_name = setting_name
      end

      def has_text?(text)
        find_row(@setting_name).has_text?(text)
      end

      def find_row(setting_name)
        page.find(change_row_selector(setting_name))
      end

      def change_row_selector(setting_name)
        ".upcoming-change-row[data-upcoming-change='#{setting_name}']"
      end

      def has_status?(status)
        find_row(@setting_name).has_css?(".upcoming-change__badge.--status-#{status}")
      end

      def has_impact_role?(impact_type)
        find_row(@setting_name).has_css?(".upcoming-change__badge.--impact-role-#{impact_type}")
      end

      def has_plugin_name?(plugin_name)
        find_row(@setting_name).find(".upcoming-change__plugin").has_text?(plugin_name)
      end

      def toggle
        PageObjects::Components::DToggleSwitch.new(
          "#{change_row_selector(@setting_name)} .upcoming-change__toggle",
        ).toggle
      end

      def enabled?
        PageObjects::Components::DToggleSwitch.new(
          "#{change_row_selector(@setting_name)} .upcoming-change__toggle",
        ).checked?
      end

      def disabled?
        PageObjects::Components::DToggleSwitch.new(
          "#{change_row_selector(@setting_name)} .upcoming-change__toggle",
        ).unchecked?
      end
    end
  end
end
