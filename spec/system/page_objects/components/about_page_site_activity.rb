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

      def visitors
        AboutPageSiteActivityItem.new(
          container.find(".about__activities-item.visitors"),
          translation_key: nil,
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

      # used by plugins
      def custom(name, translation_key: nil)
        AboutPageSiteActivityItem.new(
          container.find(".about__activities-item.#{name}"),
          translation_key:,
        )
      end

      def has_activity_item?(name)
        container.has_css?(".about__activities-item.#{name}")
      end

      def has_no_activity_item?(name)
        container.has_no_css?(".about__activities-item.#{name}")
      end
    end
  end
end
