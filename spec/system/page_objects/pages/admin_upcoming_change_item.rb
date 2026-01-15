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

      def select_enabled_for(option)
        enabled_for_dropdown.select(option)
      end

      def save_groups
        find_item(@setting_name).find(".upcoming-change__save-groups").click
      end

      def enabled?
        enabled_for != "no_one"
      end

      def disabled?
        enabled_for == "no_one"
      end

      def enabled_for
        enabled_for_dropdown.value
      end

      def enabled_for_dropdown
        PageObjects::Components::DSelect.new(
          "#{change_item_selector(@setting_name)} .upcoming-change__enabled-for",
        )
      end

      def group_selector
        PageObjects::Components::GroupSelector.new(change_item_selector(@setting_name))
      end

      def has_no_group_selector?
        expect(group_selector).to be_hidden
      end

      def has_groups?(*group_names)
        group_selector.has_selected_groups?(*group_names)
      end

      def has_no_groups?
        group_selector.has_no_selected_groups?
      end

      def add_group(group_name)
        group_selector.add_group(group_name)
      end

      def remove_group(group_name)
        group_selector.remove_group(group_name)
      end
    end
  end
end
