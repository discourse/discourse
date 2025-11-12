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

      def has_selected_groups?(*group_names)
        selected_groups =
          find("#{@context} .group-selector")
            .all(".d-multi-select-trigger__selected-item")
            .map { |item| item[:innerText] }
        expect(selected_groups & group_names).to match_array(group_names)
      end

      def open
        find(@context).find(".group-selector .d-multi-select-trigger__expand-btn").click
        expect(page).to have_css(".fk-d-menu.d-multi-select-content")
      end

      def add_group(group_name)
        self.open
        find(".dropdown-menu__item.d-multi-select__search-container").fill_in(with: group_name)
        find(".dropdown-menu__item.d-multi-select__result[title='#{group_name}']").click
        find(@context).find(".upcoming-change__save-groups").click
      end

      def remove_group(group_name)
        find(@context)
          .find(".group-selector .d-multi-select-trigger__selected-item", text: group_name)
          .find(".d-multi-select-trigger__remove-selection-icon")
          .click
        find(@context).find(".upcoming-change__save-groups").click
      end
    end
  end
end
