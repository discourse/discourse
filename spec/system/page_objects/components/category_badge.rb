# frozen_string_literal: true

module PageObjects
  module Components
    class CategoryBadge < PageObjects::Components::Base
      SELECTOR = ".badge-category__wrapper"

      def find(category)
        page.find(SELECTOR).find(".badge-category[data-category-id='#{category.id}']")
      end
    end
  end
end
