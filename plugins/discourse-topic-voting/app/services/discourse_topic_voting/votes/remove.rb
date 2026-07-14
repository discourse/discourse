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

        step :enqueue_topic_unvote_webhook
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

      def destroy_active_vote(active_vote:)
        active_vote.destroy!
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
    end
  end
end
