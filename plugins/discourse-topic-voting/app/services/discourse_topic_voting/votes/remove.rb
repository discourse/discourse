# frozen_string_literal: true

module DiscourseTopicVoting
  module Votes
    class Remove
      include Service::Base

      params do
        attribute :topic_id, :integer

        validates :topic_id, presence: true
      end

      model :topic
      policy :can_see_topic
      model :active_vote, optional: true

      only_if :active_vote_present? do
        transaction do
          step :destroy_active_vote
          step :refresh_vote_count
        end

        only_if :vote_destroyed? do
          step :enqueue_topic_unvote_webhook
          step :publish_vote_destroyed_event
        end
      end

      private

      def fetch_topic(params:)
        Topic.find_by(id: params.topic_id)
      end

      def can_see_topic(guardian:, topic:)
        guardian.can_see?(topic)
      end

      def fetch_active_vote(guardian:, topic:)
        DiscourseTopicVoting::Vote.find_by(user: guardian.user, topic: topic, archive: false)
      end

      def active_vote_present?(active_vote:)
        active_vote.present?
      end

      # A concurrent removal of the same vote finds nothing left to delete, so it reports nothing.
      def destroy_active_vote(active_vote:)
        context[:vote_destroyed] = DiscourseTopicVoting::Vote.where(id: active_vote.id).delete_all >
          0
      end

      def vote_destroyed?(vote_destroyed:)
        vote_destroyed
      end

      def refresh_vote_count(topic:)
        topic.update_vote_count
      end

      def enqueue_topic_unvote_webhook(guardian:, topic:)
        return if !WebHook.active_web_hooks(:topic_unvote).exists?

        payload = {
          topic_id: topic.id,
          topic_slug: topic.slug,
          voter_id: guardian.user.id,
          vote_count: topic.vote_count,
        }

        WebHook.enqueue_topic_voting_hooks(:topic_unvote, topic, payload.to_json)
      end

      def publish_vote_destroyed_event(active_vote:, guardian:)
        DiscourseEvent.trigger(
          :topic_voting_vote_destroyed,
          active_vote,
          acting_user: guardian.user,
        )
      end
    end
  end
end
