# frozen_string_literal: true

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Nodes
      module TopicReceivedVote
        class V2 < V1
          description(
            superclass.description.merge(
              version: "2.0",
              output_contracts: [
                {
                  schema:
                    DiscourseTopicVoting::Workflows::Schema::TOPIC_RECEIVED_VOTE_V2_OUTPUT_SCHEMA,
                },
              ],
            ),
          )

          def output
            super.then { |data| data.merge(user: serialize_user(topic.user), actor: data[:user]) }
          end
        end
      end
    end
  end
end
