# frozen_string_literal: true

module PageObjects
  module Components
    # NOTE: GroupSelector is the only user of the DMultiSelect component at the moment.
    # At some point, we might want to make a separate PageObject for DMultiSelect if
    # more components start using it.
    class GroupSelector < PageObjects::Components::Base
      def initialize(context)
        @context = context
      end

      def hidden?
        have_count(0).matches?(
          browser_root
            .locator("#{@context}")
            .filter(visible: true)
            .tap do |parent|
              parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
            end
            .locator(".group-selector")
            .filter(visible: true),
        )
      end

      def has_selected_groups?(*group_names)
        selected_groups =
          browser_root
            .locator("#{@context} .group-selector")
            .filter(visible: true)
            .locator(".d-multi-select-trigger__selected-item")
            .filter(visible: true)
            .tap { |elements| elements.first.wait_for(state: "visible") }
            .all
            .map do |item|
              item.evaluate(
                "(element, name) => { const value = element[name]; return value !== null && value !== undefined && value !== false && !['object', 'function'].includes(typeof value) ? value : element.getAttribute(name); }",
                arg: "innerText",
              )
            end
        expect(selected_groups & group_names).to match_array(group_names)
      end

      def has_no_selected_groups?
        have_count(0).matches?(
          browser_root
            .locator("#{@context} .group-selector")
            .filter(visible: true)
            .tap do |parent|
              parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
            end
            .locator(".d-multi-select-trigger__selected-item")
            .filter(visible: true),
        )
      end

      def open
        browser_root
          .locator(@context)
          .filter(visible: true)
          .locator(".group-selector .d-multi-select-trigger__expand-btn")
          .filter(visible: true)
          .click
        expect(
          browser_root.locator(".fk-d-menu.d-multi-select-content").filter(visible: true),
        ).not_to have_count(0)
      end

      def add_group(group_name)
        self.open
        browser_root
          .locator(".dropdown-menu__item.d-multi-select__search-container input")
          .filter(visible: true)
          .fill(group_name)
        browser_root
          .locator(".dropdown-menu__item.d-multi-select__result[title='#{group_name}']")
          .filter(visible: true)
          .click
      end

      def remove_group(group_name)
        browser_root
          .locator(@context)
          .filter(visible: true)
          .locator(".group-selector .d-multi-select-trigger__selected-item")
          .filter(visible: true)
          .filter(hasText: browser_text_pattern(group_name))
          .locator(".d-multi-select-trigger__remove-selection-icon")
          .filter(visible: true)
          .click
      end
    end
  end
end
