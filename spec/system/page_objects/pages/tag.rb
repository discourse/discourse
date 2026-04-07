# frozen_string_literal: true

module PageObjects
  module Pages
    class Tag < PageObjects::Pages::Base
      def visit_tag(tag)
        page.visit "/tag/#{tag.slug_for_url}/#{tag.id}"
        self
      end

      def tag_info_btn
        find("#show-tag-info")
      end

      def has_tag_info_btn?
        has_css?("#show-tag-info")
      end

      def has_no_tag_info_btn?
        has_no_css?("#show-tag-info")
      end

      def has_no_tag?(name)
        has_no_css?(".tag-box", text: name)
      end

      def tags_dropdown
        PageObjects::Components::SelectKit.new(".select-kit.tag-drop")
      end
    end
  end
end
