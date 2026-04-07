# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module PostCreated
      class V1 < NodeType
        def self.identifier
          "trigger:post_created"
        end

        def self.icon
          "comment"
        end

        def self.color_key
          "indigo"
        end

        def self.palette_group_id
          "discourse_triggers"
        end

        def self.event_name
          :post_created
        end

        def self.output_schema
          { post: Schemas::Post.fields, topic: Schemas::Topic.fields }
        end

        def initialize(post, opts = nil, *)
          super(configuration: {})
          @post = post
          @opts = opts
        end

        def valid?
          @post.present? && @post.topic.present? && @post.post_type == Post.types[:regular] &&
            !skip_workflows?(@opts)
        end

        def output
          { post: Schemas::Post.resolve(@post), topic: Schemas::Topic.resolve(@post.topic) }
        end
      end
    end
  end
end
