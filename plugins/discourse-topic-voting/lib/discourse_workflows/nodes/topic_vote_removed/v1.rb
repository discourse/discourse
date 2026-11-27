# frozen_string_literal: true

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Nodes
      module TopicVoteRemoved
        # Only voters remove their own vote, so the vote's user is the actor, as for Topic received vote.
        class V1 < TopicReceivedVote::V2
          description(
            TopicReceivedVote::V2.description.merge(
              name: "trigger:topic_vote_removed",
              version: "1.0",
              defaults: {
                icon: "far-thumbs-down",
                color: "purple",
              },
              event: :topic_voting_vote_destroyed,
              i18n_scope: "topic_received_vote",
            ),
          )
        end
      end
    end
  end
end
