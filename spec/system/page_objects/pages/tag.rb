# frozen_string_literal: true

module PageObjects
  module Pages
    class Tag < PageObjects::Pages::Base
      def visit_tag(tag)
        browser_page
          .goto("/tag/#{tag.slug_for_url}/#{tag.id}")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def tag_info_btn
        browser_root.locator("#show-tag-info").filter(visible: true)
      end

      def has_tag_info_btn?
        have_count(0).does_not_match?(browser_root.locator("#show-tag-info").filter(visible: true))
      end

      def has_no_tag_info_btn?
        have_count(0).matches?(browser_root.locator("#show-tag-info").filter(visible: true))
      end

      def edit_tag_btn
        browser_root.locator("#edit-tag").filter(visible: true)
      end

      def has_edit_tag_btn?
        have_count(0).does_not_match?(browser_root.locator("#edit-tag").filter(visible: true))
      end

      def has_no_edit_tag_btn?
        have_count(0).matches?(browser_root.locator("#edit-tag").filter(visible: true))
      end

      def has_no_tag?(name)
        contain_text([browser_text_pattern(name)], useInnerText: true).does_not_match?(
          browser_root.locator(".tag-box").filter(visible: true),
        )
      end

      def tags_dropdown
        PageObjects::Components::SelectKit.new(".select-kit.tag-drop")
      end
    end
  end
end
