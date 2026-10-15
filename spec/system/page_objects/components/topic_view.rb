# frozen_string_literal: true

module PageObjects
  module Components
    class TopicView < PageObjects::Components::Base
      def has_read_post?(post)
        PlaywrightMatchers.have_count(
          0,
          timeout: (Capybara.default_max_wait_time * 2) * 1000,
        ).does_not_match?(browser_root.locator("#post_#{post.post_number} .read-state.read"))
      end

      def has_tracking_status?(name)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(
            "#topic-footer-buttons .notifications-tracking-trigger[data-level-name='#{name}']",
          ).filter(visible: true),
        )
      end
    end
  end
end
