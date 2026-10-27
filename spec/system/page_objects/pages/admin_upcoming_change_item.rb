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

      def has_permanent_soon_notice?
        find_item(@setting_name).has_css?(".upcoming-change__status-notice")
      end

      def has_no_permanent_soon_notice?
        find_item(@setting_name).has_no_css?(".upcoming-change__status-notice")
      end

      def has_depends_on_notice?(text)
        find_item(@setting_name).has_css?(".upcoming-change__depends-on-notice", text: text)
      end

      def has_no_depends_on_notice?
        find_item(@setting_name).has_no_css?(".upcoming-change__depends-on-notice")
      end

      def toggle_switch
        PageObjects::Components::DToggleSwitch.new(
          "#{change_item_selector(@setting_name)} .upcoming-change__enabled",
        )
      end

      def toggle
        toggle_switch.toggle
      end

      def enabled?
        toggle_switch.checked?
      end

      def disabled?
        toggle_switch.unchecked?
      end

      def toggle_groups
        find_item(@setting_name).find(".upcoming-change__edit-groups").click
      end

      def has_group_button?
        find_item(@setting_name).has_css?(".upcoming-change__edit-groups")
      end

      def has_no_group_button?
        find_item(@setting_name).has_no_css?(".upcoming-change__edit-groups")
      end

      def group_selector
        PageObjects::Components::SelectKit.new(
          "#{change_item_selector(@setting_name)} .email-group-user-chooser",
        )
      end

      def has_no_group_selector?
        find_item(@setting_name).has_no_css?(".email-group-user-chooser")
      end

      def open_group_selector
        if group_selector.is_collapsed?
          group_selector.collapsed_component.find(".select-kit-header").send_keys(:enter)
        end
      end

      def has_groups?(*group_names)
        open_group_selector
        group_names.all? do |group_name|
          find_item(@setting_name).has_css?(".selected-choice[data-value='#{group_name}']")
        end
      end

      def has_no_groups?
        find_item(@setting_name).has_no_css?(".selected-choice")
      end

      def add_group(group_name)
        open_group_selector
        group_selector.search(group_name)
        group_selector.select_row_by_value(group_name)
      end

      def remove_group(group_name)
        open_group_selector
        find_item(@setting_name).find(".selected-choice[data-value='#{group_name}']").click
      end

      def save_groups
        find_item(@setting_name).find(".upcoming-change__save-groups").click
      end

      def has_disabled_group_save?
        find_item(@setting_name).has_css?(".upcoming-change__save-groups[disabled]")
      end

      def has_empty_groups_description?
        find_item(@setting_name).has_css?(
          ".upcoming-change__groups-description",
          text: I18n.t("admin_js.admin.upcoming_changes.toggle_instead_of_empty_groups"),
        )
      end

      def has_staff_description?
        find_item(@setting_name).has_css?(
          ".upcoming-change__groups-description",
          text: I18n.t("admin_js.admin.upcoming_changes.staff_always_included"),
        )
      end

      def has_locked_group?(group_name)
        open_group_selector
        find_item(@setting_name).has_css?(
          ".selected-choice[data-value='#{group_name}'] .d-icon-lock",
        )
      end
    end
  end
end
