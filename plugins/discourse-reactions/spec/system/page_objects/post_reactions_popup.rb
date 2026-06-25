# frozen_string_literal: true

module PageObjects
  module Components
    class PostReactionsPopup < PageObjects::Components::Base
      SELECTOR = ".users-popup"

      def open?
        page.has_css?(SELECTOR)
      end

      def closed?
        page.has_no_css?(SELECTOR)
      end

      def click_filter(reaction)
        find("#{SELECTOR} [data-reaction-filter=#{reaction}]").click
      end

      def has_user?(username)
        page.has_css?("#{SELECTOR} .users-popup__name[data-user-card=#{username}]")
      end

      def has_no_user?(username)
        page.has_no_css?("#{SELECTOR} .users-popup__name[data-user-card=#{username}]")
      end
    end
  end
end
