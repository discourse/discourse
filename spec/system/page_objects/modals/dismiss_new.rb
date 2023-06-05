# frozen_string_literal: true

module PageObjects
  module Modals
    class DismissNew < PageObjects::Modals::Base
      def dismiss_topics_checkbox
        find(".dismiss-topics input")
      end

      def dismiss_posts_checkbox
        find(".dismiss-posts input")
      end

      def untrack_checkbox
        find(".untrack input")
      end
    end
  end
end
