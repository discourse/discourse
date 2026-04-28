# frozen_string_literal: true

module DiscourseTopicVoting
  module Votes
    class Cast
      include Service::Base

      params do
        attribute :topic_id, :integer

        validates :topic_id, presence: true
      end

      model :topic

      policy :can_see_topic
      policy :topic_is_votable
      policy :topic_not_already_voted
      policy :current_user_can_vote

      transaction do
        step :create_vote
        step :refresh_vote_count
      end

      step :enqueue_backfill_badges
      step :enqueue_topic_upvote_webhook

      private

      def fetch_topic(params:)
        Topic.find_by(id: params.topic_id)
      end

      def can_see_topic(guardian:, topic:)
        guardian.can_see?(topic)
      end

      def topic_is_votable(topic:)
        topic.can_vote?
      end

      def topic_not_already_voted(guardian:, topic:)
        !topic.user_voted?(guardian.user)
      end

      def current_user_can_vote(guardian:)
        guardian.user.can_vote?
      end

      def create_vote(guardian:, topic:)
        DiscourseTopicVoting::Vote.create!(user: guardian.user, topic: topic)
      end

      def refresh_vote_count(topic:)
        topic.update_vote_count
      end

      def enqueue_backfill_badges(topic:)
        Jobs.enqueue(Jobs::DiscourseTopicVoting::BackfillBadges, topic_id: topic.id)
      end

      def enqueue_topic_upvote_webhook(guardian:, topic:)
        return if !WebHook.active_web_hooks(:topic_upvote).exists?

        payload = {
          topic_id: topic.id,
          topic_slug: topic.slug,
          voter_id: guardian.user.id,
          vote_count: topic.vote_count,
        }

        WebHook.enqueue_topic_voting_hooks(:topic_upvote, topic, payload.to_json)
      end
    end
  end
end
