# frozen_string_literal: true

module PageObjects
  module Components
    class AboutPageSiteActivity < PageObjects::Components::Base
      attr_reader :container

      def initialize(container)
        @container = container
      end

      def topics
        AboutPageSiteActivityItem.new(
          container.locator(".about__activities-item.topics").filter(visible: true),
          translation_key: "about.activities.topics",
        )
      end

      def posts
        AboutPageSiteActivityItem.new(
          container.locator(".about__activities-item.posts").filter(visible: true),
          translation_key: "about.activities.posts",
        )
      end

      def visitors
        AboutPageSiteActivityItem.new(
          container.locator(".about__activities-item.visitors").filter(visible: true),
          translation_key: nil,
        )
      end

      def active_users
        AboutPageSiteActivityItem.new(
          container.locator(".about__activities-item.active-users").filter(visible: true),
          translation_key: "about.activities.active_users",
        )
      end

      def sign_ups
        AboutPageSiteActivityItem.new(
          container.locator(".about__activities-item.sign-ups").filter(visible: true),
          translation_key: "about.activities.sign_ups",
        )
      end

      def likes
        AboutPageSiteActivityItem.new(
          container.locator(".about__activities-item.likes").filter(visible: true),
          translation_key: "about.activities.likes",
        )
      end

      # used by plugins
      def custom(name, translation_key: nil)
        AboutPageSiteActivityItem.new(
          container.locator(".about__activities-item.#{name}").filter(visible: true),
          translation_key:,
        )
      end

      def has_activity_item?(name)
        PlaywrightMatchers.have_count(0).does_not_match?(
          container.locator(".about__activities-item.#{name}").filter(visible: true),
        )
      end

      def has_no_activity_item?(name)
        PlaywrightMatchers.have_count(0).matches?(
          container
            .tap do |parent|
              parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
            end
            .locator(".about__activities-item.#{name}")
            .filter(visible: true),
        )
      end
    end
  end
end
