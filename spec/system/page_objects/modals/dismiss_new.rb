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

      def has_untrack_unchecked?
        find(".untrack label").has_no_checked_field?
      end
    end
  end
end
