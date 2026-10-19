# frozen_string_literal: true

module PageObjects
  module Components
    class NestedActivityLog < PageObjects::Components::Base
      MODAL_SELECTOR = ".nested-activity-log-modal"

      def open?
        have_count(0).does_not_match?(browser_root.locator(MODAL_SELECTOR).filter(visible: true))
      end

      def closed?
        have_count(0).matches?(browser_root.locator(MODAL_SELECTOR).filter(visible: true))
      end

      def has_item?(post)
        have_count(0).does_not_match?(
          browser_root.locator(item_selector(post)).filter(visible: true),
        )
      end

      def has_item_text?(post, text)
        contain_text([browser_text_pattern(text)], useInnerText: true).matches?(
          browser_root.locator(item_selector(post)).filter(visible: true),
        )
      end

      def has_item_count?(count)
        have_count(count).matches?(
          browser_root.locator("#{MODAL_SELECTOR} .nested-activity-log-modal__item").filter(
            visible: true,
          ),
        )
      end

      def has_edit_button?(post)
        have_count(0).does_not_match?(
          browser_root.locator("#{item_selector(post)} .small-action-edit").filter(visible: true),
        )
      end

      def has_no_edit_button?(post)
        have_count(0).matches?(
          browser_root.locator("#{item_selector(post)} .small-action-edit").filter(visible: true),
        )
      end

      def has_delete_button?(post)
        have_count(0).does_not_match?(
          browser_root.locator("#{item_selector(post)} .small-action-delete").filter(visible: true),
        )
      end

      def has_recover_button?(post)
        have_count(0).does_not_match?(
          browser_root.locator("#{item_selector(post)} .small-action-recover").filter(
            visible: true,
          ),
        )
      end

      def click_edit(post)
        browser_root
          .locator("#{item_selector(post)} .small-action-edit")
          .filter(visible: true)
          .click
        self
      end

      def click_delete(post)
        browser_root
          .locator("#{item_selector(post)} .small-action-delete")
          .filter(visible: true)
          .click
        self
      end

      def click_recover(post)
        browser_root
          .locator("#{item_selector(post)} .small-action-recover")
          .filter(visible: true)
          .click
        self
      end

      def click_load_more
        browser_root
          .locator("#{MODAL_SELECTOR} .nested-activity-log-modal__load-more button")
          .filter(visible: true)
          .click
        self
      end

      private

      def item_selector(post)
        "#{MODAL_SELECTOR} [data-post-id='#{post.id}']"
      end
    end
  end
end
