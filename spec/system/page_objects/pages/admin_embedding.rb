# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminEmbedding < PageObjects::Pages::Base
      def visit
        page.visit("/admin/customize/embedding")
        self
      end

      def click_posts_and_topics_tab
        find(".admin-embedding-tabs__posts-and-topics").click
      end

      def click_hosts_tab
        find(".admin-embedding-tabs__hosts").click
      end

      def click_add_host
        find(".admin-embedding__header-add-host").click
        self
      end

      def click_edit_host
        find(".admin-embeddable-host-item__edit").click
        self
      end

      def click_delete
        find(".admin-embeddable-host-item__delete").click
        self
      end

      def confirm_delete
        find(".dialog-footer .btn-primary").click
        expect(page).to have_no_css(".dialog-body", wait: Capybara.default_max_wait_time * 3)
        self
      end
    end
  end
end
