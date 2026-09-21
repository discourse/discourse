# frozen_string_literal: true

module DiscourseRewind
  module Action
    class BaseReport < Service::ActionBase
      option :user
      option :date

      def call
        raise NotImplementedError
      end

      def self.publicly_visible_topics
        Topic.listable_topics.visible.secured
      end

      def self.publicly_visible_posts
        Post.visible.merge(publicly_visible_topics).where.not(post_type: Post.types[:whisper])
      end

      def self.enabled?
        true
      end

      def should_use_fake_data?
        return false if ENV["DISCOURSE_REWIND_USE_REAL_DATA"] == "1"
        Rails.env.development?
      end
    end
  end
end
