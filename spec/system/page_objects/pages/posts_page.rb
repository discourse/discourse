# frozen_string_literal: true

module PageObjects
  module Pages
    class Posts < PageObjects::Pages::Base
      POSTS_PAGE_SELECTOR = ".posts-page"

      def visit
        page.visit("/posts")
        self
      end

      def has_page_title?
        page.find("#{POSTS_PAGE_SELECTOR} .posts-page__title")
      end

      def has_posts?(count)
        page.has_css?("#{POSTS_PAGE_SELECTOR} .post-list .post-list-item", count: count)
      end
    end
  end
end
