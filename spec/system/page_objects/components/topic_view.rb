# frozen_string_literal: true

module PageObjects
  module Components
    class TopicView < PageObjects::Components::Base
      def has_read_post?(post)
        page.has_css?(
          "#post_#{post.post_number} .read-state.read",
          visible: false,
          wait: Capybara.default_max_wait_time * 2,
        )
      end
    end
  end
end
