# frozen_string_literal: true

module PageObjects
  module Pages
    class UserActivityBookmarks < PageObjects::Pages::Base
      def visit(user, q: nil)
        url = "/u/#{user.username_lower}/activity/bookmarks"
        url += "?q=#{q}" if q
        page.visit(url)
        self
      end

      def search_for(query)
        fill_in("bookmark-search", with: query)
        page.find(".bookmark-search-form button").click
        self
      end

      def has_topic?(topic)
        has_content?(topic.title)
      end

      def has_no_topic?(topic)
        has_no_content?(topic.title)
      end
    end
  end
end
