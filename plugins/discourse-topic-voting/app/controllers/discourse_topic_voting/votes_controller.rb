# frozen_string_literal: true

module DiscourseTopicVoting
  class VotesController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    before_action :ensure_logged_in

    def who
      params.require(:topic_id)
      topic = Topic.find(params[:topic_id].to_i)
      guardian.ensure_can_see!(topic)

      render json: MultiJson.dump(who_voted(topic))
    end

    def vote
      topic_id = params["topic_id"].to_i
      topic = Topic.find_by(id: topic_id)

      raise Discourse::InvalidAccess if !topic.can_vote? || topic.user_voted?(current_user)
      guardian.ensure_can_see!(topic)

      voted = false

      if current_user.can_vote?
        DiscourseTopicVoting::Vote.find_or_create_by(user: current_user, topic_id: topic_id)

        topic.update_vote_count
        voted = true
      end

      obj = voting_response(topic)
      obj[:alert] = current_user.alert_low_votes?

      if WebHook.active_web_hooks(:topic_upvote).exists?
        payload = {
          topic_id: topic_id,
          topic_slug: topic.slug,
          voter_id: current_user.id,
          vote_count: obj[:vote_count],
        }
        WebHook.enqueue_topic_voting_hooks(:topic_upvote, topic, payload.to_json)
      end

      render json: obj, status: voted ? 200 : 403
    end

    def unvote
      topic_id = params["topic_id"].to_i
      topic = Topic.find_by(id: topic_id)

      guardian.ensure_can_see!(topic)

      DiscourseTopicVoting::Vote.destroy_by(user: current_user, topic_id: topic_id)

      topic.update_vote_count

      obj = voting_response(topic)

      if WebHook.active_web_hooks(:topic_unvote).exists?
        payload = {
          topic_id: topic_id,
          topic_slug: topic.slug,
          voter_id: current_user.id,
          vote_count: obj[:vote_count],
        }
        WebHook.enqueue_topic_voting_hooks(:topic_unvote, topic, payload.to_json)
      end

      render json: obj
    end

    protected

    def voting_response(topic)
      {
        can_vote: current_user.can_vote?,
        vote_limit: current_user.vote_limit,
        vote_count: topic.vote_count,
        who_voted: who_voted(topic),
        votes_left: current_user.votes_left,
      }
    end

    def who_voted(topic)
      return nil unless SiteSetting.topic_voting_show_who_voted

      ActiveModel::ArraySerializer.new(
        topic.who_voted,
        scope: guardian,
        each_serializer: BasicUserSerializer,
      )
    end
  end
end
