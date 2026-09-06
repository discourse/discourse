# frozen_string_literal: true

module PageObjects
  module Components
    class NestedActivityLog < PageObjects::Components::Base
      MODAL_SELECTOR = ".nested-activity-log-modal"

      def open?
        has_css?(MODAL_SELECTOR)
      end

      def closed?
        has_no_css?(MODAL_SELECTOR)
      end

      def has_item?(post)
        has_css?(item_selector(post))
      end

      def has_item_text?(post, text)
        has_css?(item_selector(post), text: text)
      end

      def has_item_count?(count)
        has_css?("#{MODAL_SELECTOR} .nested-activity-log-modal__item", count: count)
      end

      def has_edit_button?(post)
        has_css?("#{item_selector(post)} .small-action-edit")
      end

      def has_no_edit_button?(post)
        has_no_css?("#{item_selector(post)} .small-action-edit")
      end

      def has_delete_button?(post)
        has_css?("#{item_selector(post)} .small-action-delete")
      end

      def has_recover_button?(post)
        has_css?("#{item_selector(post)} .small-action-recover")
      end

      def click_edit(post)
        find("#{item_selector(post)} .small-action-edit").click
        self
      end

      def click_delete(post)
        find("#{item_selector(post)} .small-action-delete").click
        self
      end

      def click_recover(post)
        find("#{item_selector(post)} .small-action-recover").click
        self
      end

      def click_load_more
        find("#{MODAL_SELECTOR} .nested-activity-log-modal__load-more button").click
        self
      end

      private

      def item_selector(post)
        "#{MODAL_SELECTOR} [data-post-id='#{post.id}']"
      end
    end
  end
end
