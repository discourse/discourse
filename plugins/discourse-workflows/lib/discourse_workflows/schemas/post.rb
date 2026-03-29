# frozen_string_literal: true

module DiscourseWorkflows
  module Schemas
    class Post
      BASE_FIELDS = {
        id: :integer,
        post_number: :integer,
        raw: :string,
        reply_to_post_number: :integer,
        is_first_post: :boolean,
        via_email: :boolean,
        username: :string,
        user_id: :integer,
      }.freeze

      def self.fields
        BASE_FIELDS
      end

      def self.resolve(post)
        return {} if post.nil?

        {
          id: post.id,
          post_number: post.post_number,
          raw: post.raw,
          reply_to_post_number: post.reply_to_post_number,
          is_first_post: post.is_first_post?,
          via_email: post.via_email?,
          username: post.user&.username,
          user_id: post.user_id,
        }
      end
    end
  end
end
