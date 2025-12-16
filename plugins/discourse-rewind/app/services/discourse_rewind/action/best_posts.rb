# frozen_string_literal: true

module DiscourseRewind
  module Action
    class BestPosts < BaseReport
      FakeData = {
        data: [
          {
            post_number: 5,
            topic_id: 42,
            like_count: 23,
            reply_count: 8,
            excerpt: "This is a great explanation of how ActiveRecord works under the hood...",
          },
          {
            post_number: 12,
            topic_id: 89,
            like_count: 19,
            reply_count: 5,
            excerpt:
              "Here's a comprehensive guide to testing Rails applications with RSpec and system tests...",
          },
          {
            post_number: 3,
            topic_id: 156,
            like_count: 15,
            reply_count: 12,
            excerpt:
              "The key to understanding PostgreSQL performance is looking at your query plans...",
          },
        ],
        identifier: "best-posts",
      }

      def call
        return FakeData if should_use_fake_data?
        best_posts =
          Post
            .public_posts
            .joins(topic: :category)
            .where(user_id: user.id)
            .where(posts: { created_at: date, deleted_at: nil })
            .where("post_number > 1")
            .where("NOT categories.read_restricted")
            .order("like_count DESC NULLS LAST, posts.created_at ASC")
            .limit(3)
            .select(:post_number, :topic_id, :like_count, :reply_count, :raw, :cooked)
            .map do |post|
              {
                post_number: post.post_number,
                topic_id: post.topic_id,
                like_count: post.like_count,
                reply_count: post.reply_count,
                excerpt:
                  post.excerpt(200, { strip_links: true, remap_emoji: true, keep_images: true }),
              }
            end

        { data: best_posts, identifier: "best-posts" }
      end
    end
  end
end
