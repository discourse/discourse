# frozen_string_literal: true

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Nodes
      module TopicReceivedVote
        class V1 < DiscourseWorkflows::NodeType
          description(
            name: "trigger:topic_received_vote",
            version: "1.0",
            defaults: {
              icon: "vote-up",
              color: "purple",
            },
            group: "discourse_triggers",
            event: :topic_voting_vote_created,
            available: -> { SiteSetting.topic_voting_enabled },
            unavailable_reason_key: "discourse_workflows.node_unavailable.requires_topic_voting",
            output_contracts: [
              {
                schema: DiscourseTopicVoting::Workflows::Schema::TOPIC_RECEIVED_VOTE_OUTPUT_SCHEMA,
              },
            ],
            properties: {
              category_ids: {
                type: :array,
                required: false,
                ui: {
                  control: :category,
                  multiple: true,
                },
              },
              include_subcategories: {
                type: :boolean,
                required: false,
                default: true,
                ui: {
                  control: :checkbox,
                },
                display_options: {
                  show: {
                    category_ids: [{ condition: { exists: true } }],
                  },
                },
              },
              tag_names: {
                type: :string,
                required: false,
                ui: {
                  control: :tags,
                },
              },
            },
          )

          def initialize(vote, *)
            super(parameters: {})
            @vote = vote
          end

          def valid?
            @vote.present? && topic.present? && voter.present?
          end

          def output
            {
              topic: serialize_record(topic, TopicListItemSerializer),
              user: serialize_user(voter),
              vote: {
                id: @vote.id,
                count: topic.vote_count,
                created_at: @vote.created_at.iso8601,
              },
            }
          end

          def matches?(trigger_ctx)
            matches_category_ids?(
              topic.category_id,
              category_ids_parameter(trigger_ctx),
              include_subcategories: trigger_ctx.get_node_parameter("include_subcategories", true),
            ) && matches_tags?(normalize_tag_names(trigger_ctx.get_node_parameter("tag_names")))
          end

          private

          def topic
            @topic ||= @vote&.topic
          end

          def voter
            @voter ||= @vote&.user
          end

          def matches_tags?(tag_names)
            tag_names.empty? || (topic.tags.pluck(:name) & tag_names).any?
          end
        end
      end
    end
  end
end
