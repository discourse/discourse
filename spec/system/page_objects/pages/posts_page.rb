# frozen_string_literal: true

module PageObjects
  module Pages
    class Posts < PageObjects::Pages::Base
      POSTS_PAGE_SELECTOR = ".posts-page"

      def visit
        browser_page.goto("/posts").tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def has_page_title?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator("#{POSTS_PAGE_SELECTOR} .posts-page__title").filter(visible: true),
        )
      end

      def has_posts?(count)
        PlaywrightMatchers.have_count(count).matches?(
          browser_root.locator("#{POSTS_PAGE_SELECTOR} .post-list .post-list-item").filter(
            visible: true,
          ),
        )
      end
    end
  end
end
