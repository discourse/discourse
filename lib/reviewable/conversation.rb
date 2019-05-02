# frozen_string_literal: true

class Reviewable < ActiveRecord::Base
  class Conversation
    include ActiveModel::Serialization

    class Post
      include ActiveModel::Serialization
      attr_reader :id, :user, :excerpt

      def initialize(post)
        @user = post.user
        @id = post.id
        @excerpt = FlagQuery.excerpt(post.cooked)
      end
    end

    attr_reader :id, :permalink, :has_more, :conversation_posts

    def initialize(meta_topic)
      @id = meta_topic.id
      @has_more = false
      @permalink = meta_topic.relative_url
      @posts = []

      meta_posts = meta_topic.ordered_posts.where(post_type: ::Post.types[:regular]).limit(2)

      @conversation_posts = meta_posts.map { |mp| Reviewable::Conversation::Post.new(mp) }
      @has_more = meta_topic.posts_count > 2
    end
  end
end
