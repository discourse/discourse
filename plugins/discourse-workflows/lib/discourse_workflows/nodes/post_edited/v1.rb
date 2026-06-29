# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module PostEdited
      class V1 < NodeType
        POST_SCOPE_OPTIONS = %w[first_post replies all_posts].freeze

        description(
          name: "trigger:post_edited",
          version: "1.0",
          defaults: {
            icon: "comment",
            color: "violet",
          },
          group: "discourse_triggers",
          events: [:post_edited],
          properties: {
            post_scope: {
              type: :options,
              required: true,
              default: "first_post",
              options: POST_SCOPE_OPTIONS,
            },
            category_id: {
              type: :integer,
              required: false,
              ui: {
                control: :category,
              },
            },
            tag_names: {
              type: :string,
              required: false,
              ui: {
                control: :tags,
              },
            },
            trust_levels: {
              type: :multi_options,
              required: false,
              options: trust_level_options,
            },
          },
        )

        def initialize(post, topic_changed_or_cooked = nil, revisor = nil, *)
          super(parameters: {})
          @post = post
          @cooked = topic_changed_or_cooked.is_a?(String) ? topic_changed_or_cooked : post&.cooked
          @revisor = revisor
        end

        def valid?
          @post.present? && @post.topic.present? && @post.post_type == ::Post.types[:regular] &&
            !@revisor&.opts&.dig(:skip_workflows)
        end

        def output
          {
            post: serialize_post(@post, include_cooked: true).merge(cooked: @cooked),
            topic: topic_data(@post.topic),
            user: user_data(@post.user),
          }
        end

        def matches?(trigger_ctx)
          matches_post_scope?(trigger_ctx.get_node_parameter("post_scope", "first_post")) &&
            matches_category?(trigger_ctx.get_node_parameter("category_id")) &&
            matches_tags?(normalize_tag_names(trigger_ctx.get_node_parameter("tag_names"))) &&
            matches_trust_level?(trigger_ctx.get_node_parameter("trust_levels"))
        end

        private

        def topic_data(topic)
          serialize_record(topic, TopicListItemSerializer)
        end

        def user_data(user)
          serialize_user(user)
        end

        def matches_post_scope?(post_scope)
          case post_scope
          when "all_posts"
            true
          when "replies"
            @post.post_number > 1
          else
            @post.post_number == 1
          end
        end

        def matches_category?(category_id)
          category_id.blank? || topic_category_ids.include?(category_id.to_i)
        end

        def topic_category_ids
          [@post.topic.category_id, @post.topic.category&.parent_category_id].compact
        end

        def matches_tags?(tag_names)
          tag_names.empty? || (topic_tag_names & tag_names).any?
        end

        def topic_tag_names
          @topic_tag_names ||= @post.topic.tags.pluck(:name)
        end

        def matches_trust_level?(trust_levels)
          trust_levels =
            Array.wrap(trust_levels).filter_map { |trust_level| trust_level.presence&.to_i }
          trust_levels.empty? || trust_levels.include?(@post.user.trust_level)
        end
      end
    end
  end
end
