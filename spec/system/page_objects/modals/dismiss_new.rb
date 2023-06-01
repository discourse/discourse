# frozen_string_literal: true

module PageObjects
  module Modals
    class DismissNew < PageObjects::Modals::Base
      def has_dismiss_topics_checked?
        find(".dismiss-topics input")["checked"] == "true"
      end

      def has_dismiss_posts_checked?
        find(".dismiss-posts input")["checked"] == "true"
      end

      def has_untrack_checked?
        find(".untrack input")["checked"] == "true"
      end
    end
  end
end
