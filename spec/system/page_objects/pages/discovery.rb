# frozen_string_literal: true

module PageObjects
  module Pages
    class Discovery < PageObjects::Pages::Base
      def topic_list
        Components::TopicList.new
      end

      def category_drop
        Components::SelectKit.new(".category-breadcrumb li:first-of-type .category-drop")
      end

      def subcategory_drop
        Components::SelectKit.new(".category-breadcrumb li:nth-of-type(2) .category-drop")
      end

      def tag_drop
        Components::SelectKit.new(".category-breadcrumb .tag-drop")
      end
    end
  end
end
