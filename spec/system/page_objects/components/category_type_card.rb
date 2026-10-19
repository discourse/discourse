# frozen_string_literal: true

module PageObjects
  module Components
    class CategoryTypeCard < PageObjects::Components::Base
      CATEGORY_TYPE_CARD_SELECTOR = ".category-type-cards__card"

      def find_type_card(type_id)
        browser_root.locator("#{CATEGORY_TYPE_CARD_SELECTOR}.--category-type-#{type_id}").filter(
          visible: true,
        )
      end

      def has_type_card?(type_id)
        have_count(0).does_not_match?(
          browser_root.locator("#{CATEGORY_TYPE_CARD_SELECTOR}.--category-type-#{type_id}").filter(
            visible: true,
          ),
        )
      end
    end
  end
end
