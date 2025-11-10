# frozen_string_literal: true

module PageObjects
  module Components
    class AdminUpcomingChangeItem < PageObjects::Components::Base
      def initialize(setting_name)
        @setting_name = setting_name
      end

      def has_text?(text)
        find_item(@setting_name).has_text?(text)
      end

      def find_item(setting_name)
        page.find(change_item_selector(setting_name))
      end

      def exists?
        page.has_css?(change_item_selector(@setting_name))
      end

      def does_not_exist?
        page.has_no_css?(change_item_selector(@setting_name))
      end

      def change_item_selector(setting_name)
        ".upcoming-change-row[data-upcoming-change='#{setting_name}']"
      end

      def has_status?(status)
        find_item(@setting_name).has_css?(".upcoming-change__badge.--status-#{status}")
      end

      def has_impact_role?(impact_type)
        find_item(@setting_name).has_css?(".upcoming-change__badge.--impact-role-#{impact_type}")
      end

      def has_plugin_name?(plugin_name)
        find_item(@setting_name).find(".upcoming-change__plugin").has_text?(plugin_name)
      end

      def toggle
        PageObjects::Components::DToggleSwitch.new(
          "#{change_item_selector(@setting_name)} .upcoming-change__toggle",
        ).toggle
      end

      def enabled?
        PageObjects::Components::DToggleSwitch.new(
          "#{change_item_selector(@setting_name)} .upcoming-change__toggle",
        ).checked?
      end

      def disabled?
        PageObjects::Components::DToggleSwitch.new(
          "#{change_item_selector(@setting_name)} .upcoming-change__toggle",
        ).unchecked?
      end

      def has_groups?(*group_names)
        PageObjects::Components::GroupSelector.new(
          change_item_selector(@setting_name),
        ).has_selected_groups?(*group_names)
      end

      def add_group(group_name)
        PageObjects::Components::GroupSelector.new(change_item_selector(@setting_name)).add_group(
          group_name,
        )
      end

      def remove_group(group_name)
        PageObjects::Components::GroupSelector.new(
          change_item_selector(@setting_name),
        ).remove_group(group_name)
      end
    end
  end
end
