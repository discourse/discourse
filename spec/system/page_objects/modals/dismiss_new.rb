# frozen_string_literal: true

module PageObjects
  module Modals
    class DismissNew < PageObjects::Modals::Base
      def has_dismiss_topics_checked?
        find(".dismiss-topics label").has_checked_field?
      end

      def has_dismiss_posts_checked?
        find(".dismiss-posts label").has_checked_field?
      end

      def has_dismiss_topics_unchecked?
        find(".dismiss-topics label").has_no_checked_field?
      end

      def has_dismiss_posts_unchecked?
        find(".dismiss-posts label").has_no_checked_field?
      end

      def has_untrack_unchecked?
        find(".untrack label").has_no_checked_field?
      end

      def click_dismiss
        click_button("dismiss-read-confirm")
        self
      end

      def closed?
        page.has_no_css?(".d-modal")
      end
    end
  end
end
