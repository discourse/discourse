# frozen_string_literal: true

module PageObjects
  module Components
    class CategoryCard < PageObjects::Components::Base
      CARD_CONTENT_SELECTOR = ".category-card .card-content"

      def closed?
        has_no_css?(CARD_CONTENT_SELECTOR)
      end

      def showing_category?(category)
        has_css?(
          "#{CARD_CONTENT_SELECTOR} .names__primary a[href='#{category.url}']",
          text: category.name,
        )
      end
    end
  end
end
