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

      def group_selector_selector
        "#{change_item_selector(@setting_name)} .upcoming-change__group-selector"
      end

      def group_chip_selector(group_name)
        ".d-multi-select-trigger__selected-item[title='#{group_name}']"
      end

      def has_editable_audience?
        find_item(@setting_name).has_css?(".upcoming-change__group-selector:not(.--disabled)")
      end

      def has_locked_audience?(*group_names)
        item = find_item(@setting_name)
        item.has_css?(".upcoming-change__group-selector.--disabled") &&
          item.has_no_css?(".upcoming-change__save-groups") &&
          item.has_css?(
            ".upcoming-change__groups-description",
            text: I18n.t("admin_js.admin.upcoming_changes.audience_locked"),
          ) &&
          group_names.all? do |group_name|
            item.has_css?("#{group_chip_selector(group_name)} .d-icon-lock")
          end
      end

      def open_group_selector
        return if page.has_css?(".d-multi-select__content", wait: 0)
        # The trigger's centre may land on a chip, which would remove it.
        find("#{group_selector_selector} .d-multi-select-trigger__expand-btn").click
        page.find(".d-multi-select__search-input")
      end

      def has_groups?(*group_names)
        group_names.all? do |group_name|
          find_item(@setting_name).has_css?(group_chip_selector(group_name))
        end
      end

      def has_no_groups?
        find_item(@setting_name).has_no_css?(".d-multi-select-trigger__selected-item")
      end

      def add_group(group_name)
        open_group_selector
        page.find(".d-multi-select__search-input").fill_in(with: group_name)
        page.find(".d-multi-select__result[title='#{group_name}']").click
      end

      def remove_group(group_name)
        find_item(@setting_name).find(group_chip_selector(group_name)).click
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
        find_item(@setting_name).has_css?("#{group_chip_selector(group_name)} .d-icon-lock")
      end
    end
  end
end
