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
          container.find(".about__activities-item.topics"),
          translation_key: "about.activities.topics",
        )
      end

      def posts
        AboutPageSiteActivityItem.new(
          container.find(".about__activities-item.posts"),
          translation_key: "about.activities.posts",
        )
      end

      def active_users
        AboutPageSiteActivityItem.new(
          container.find(".about__activities-item.active-users"),
          translation_key: "about.activities.active_users",
        )
      end

      def sign_ups
        AboutPageSiteActivityItem.new(
          container.find(".about__activities-item.sign-ups"),
          translation_key: "about.activities.sign_ups",
        )
      end

      def likes
        AboutPageSiteActivityItem.new(
          container.find(".about__activities-item.likes"),
          translation_key: "about.activities.likes",
        )
      end
    end
  end
end
