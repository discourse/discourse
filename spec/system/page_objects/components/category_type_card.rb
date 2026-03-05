# frozen_string_literal: true

module PageObjects
  module Components
    class CategoryTypeCard < PageObjects::Components::Base
      CATEGORY_TYPE_CARD_SELECTOR = ".category-type-cards__card"

      def find_type_card(type_id)
        find("#{CATEGORY_TYPE_CARD_SELECTOR}.--category-type-#{type_id}")
      end
    end
  end
end
