# frozen_string_literal: true

module DiscourseWorkflows
  module Triggers
    module PostCreated
      class V1 < Triggers::Base
        def self.identifier
          "trigger:post_created"
        end

        def self.event_name
          :post_created
        end

        def self.output_schema
          {
            post_id: :integer,
            post_number: :integer,
            post_raw: :string,
            reply_to_post_number: :integer,
            is_first_post: :boolean,
            via_email: :boolean,
            topic_id: :integer,
            topic_title: :string,
            tags: :array,
            category_id: :integer,
            user_id: :integer,
            username: :string,
            archetype: :string,
          }
        end

        def initialize(post, opts = nil, *)
          @post = post
          @opts = opts
        end

        def valid?
          @post.present? && @post.topic.present? && @post.post_type == Post.types[:regular] &&
            !skip_workflows?(@opts)
        end

        def output
          topic = @post.topic

          {
            post_id: @post.id,
            post_number: @post.post_number,
            post_raw: @post.raw,
            reply_to_post_number: @post.reply_to_post_number,
            is_first_post: @post.is_first_post?,
            via_email: @post.via_email?,
            topic_id: topic.id,
            topic_title: topic.title,
            tags: topic.tags.pluck(:name),
            category_id: topic.category_id,
            user_id: @post.user_id,
            username: @post.user&.username,
            archetype: topic.archetype,
          }
        end
      end
    end
  end
end
