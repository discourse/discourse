# frozen_string_literal: true

module PageObjects
  module Components
    class AdminUpcomingChangeItem < PageObjects::Components::Base
      def initialize(setting_name)
        @setting_name = setting_name
      end

      def has_displayed_text?(text)
        contain_text(browser_text_pattern(text), useInnerText: true).matches?(
          find_item(@setting_name),
        )
      end

      def find_item(setting_name)
        browser_root.locator(change_item_selector(setting_name)).filter(visible: true)
      end

      def exists?
        have_count(0).does_not_match?(
          browser_root.locator(change_item_selector(@setting_name)).filter(visible: true),
        )
      end

      def does_not_exist?
        have_count(0).matches?(
          browser_root.locator(change_item_selector(@setting_name)).filter(visible: true),
        )
      end

      def change_item_selector(setting_name)
        ".upcoming-change-row[data-upcoming-change='#{setting_name}']"
      end

      def has_status?(status)
        have_count(0).does_not_match?(
          find_item(@setting_name).locator(".upcoming-change__badge.--status-#{status}").filter(
            visible: true,
          ),
        )
      end

      def has_impact_role?(impact_type)
        have_count(0).does_not_match?(
          find_item(@setting_name).locator(
            ".upcoming-change__badge.--impact-role-#{impact_type}",
          ).filter(visible: true),
        )
      end

      def has_plugin_name?(plugin_name)
        contain_text(browser_text_pattern(plugin_name), useInnerText: true).matches?(
          find_item(@setting_name).locator(".upcoming-change__plugin").filter(visible: true),
        )
      end

      def has_permanent_soon_notice?
        have_count(0).does_not_match?(
          find_item(@setting_name).locator(".upcoming-change__status-notice").filter(visible: true),
        )
      end

      def has_no_permanent_soon_notice?
        have_count(0).matches?(
          find_item(@setting_name)
            .tap do |parent|
              parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
            end
            .locator(".upcoming-change__status-notice")
            .filter(visible: true),
        )
      end

      def has_depends_on_notice?(text)
        contain_text([browser_text_pattern(text)], useInnerText: true).matches?(
          find_item(@setting_name).locator(".upcoming-change__depends-on-notice").filter(
            visible: true,
          ),
        )
      end

      def has_no_depends_on_notice?
        have_count(0).matches?(
          find_item(@setting_name)
            .tap do |parent|
              parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
            end
            .locator(".upcoming-change__depends-on-notice")
            .filter(visible: true),
        )
      end

      def select_enabled_for(option)
        enabled_for_dropdown.select(option)
      end

      def save_groups
        find_item(@setting_name)
          .locator(".upcoming-change__save-groups")
          .filter(visible: true)
          .click
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
        PageObjects::Components::DNativeSelect.new(
          "#{change_item_selector(@setting_name)} .upcoming-change__enabled-for",
        )
      end

      def enabled_for_options
        select = enabled_for_dropdown.select_element
        select.wait_for(state: "visible")
        select.locator("option").all.map { |option| option.get_attribute("value") }
      end

      def group_selector
        PageObjects::Components::GroupSelector.new(change_item_selector(@setting_name))
      end

      def has_no_group_selector?
        expect(group_selector).to RSpecPredicates.be_hidden
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
