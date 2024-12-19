# frozen_string_literal: true

module PageObjects
  module Pages
    class GroupActivityPosts < PageObjects::Pages::Base
      def visit(group)
        page.visit("/g/#{group.name}/activity/posts")
        self
      end

      def has_user_stream_item?(count:)
        has_css?(".post-list-item", count: count)
      end

      def scroll_to_last_item
        page.execute_script <<~JS
          document.querySelector('.post-list-item:last-of-type').scrollIntoView(true);
        JS
      end
    end
  end
end
