# frozen_string_literal: true

module DiscourseTopicVoting
  class VotesController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    before_action :ensure_logged_in

    def who
      params.require(:topic_id)
      topic = Topic.find(params[:topic_id].to_i)
      guardian.ensure_can_see!(topic)

      render json: MultiJson.dump(who_voted(topic, limit: who_voted_limit))
    end

    def vote
      DiscourseTopicVoting::Votes::Cast.call(service_params) do
        on_success do |topic:|
          render json: voting_response(topic).merge(alert: current_user.alert_low_votes?)
        end
        on_failure { render json: failed_json, status: :unprocessable_entity }
        on_model_not_found(:topic) { raise Discourse::NotFound }
        on_failed_policy(:can_see_topic) { raise Discourse::InvalidAccess }
        on_failed_policy(:topic_is_votable) { raise Discourse::InvalidAccess }
        on_failed_policy(:topic_not_already_voted) { raise Discourse::InvalidAccess }
        on_failed_policy(:current_user_can_vote) do |topic:|
          render json: voting_response(topic).merge(alert: current_user.alert_low_votes?),
                 status: :forbidden
        end
        on_failed_contract do |contract|
          render json: failed_json.merge(errors: contract.errors.full_messages),
                 status: :bad_request
        end
      end
    end

    def unvote
      DiscourseTopicVoting::Votes::Remove.call(service_params) do
        on_success { |topic:| render json: voting_response(topic) }
        on_failure { render json: failed_json, status: :unprocessable_entity }
        on_model_not_found(:topic) { raise Discourse::NotFound }
        on_failed_policy(:can_see_topic) { raise Discourse::InvalidAccess }
        on_failed_contract do |contract|
          render json: failed_json.merge(errors: contract.errors.full_messages),
                 status: :bad_request
        end
      end
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

    def who_voted(topic, limit: DiscourseTopicVoting::VOTER_PREVIEW_LIMIT)
      return nil unless SiteSetting.topic_voting_show_who_voted

      ActiveModel::ArraySerializer.new(
        topic.who_voted(limit:),
        scope: guardian,
        each_serializer: BasicUserSerializer,
      )
    end

    def who_voted_limit
      limit = params[:limit].presence&.to_i
      return DiscourseTopicVoting::VOTER_PREVIEW_LIMIT if limit.blank? || limit <= 0

      [limit, DiscourseTopicVoting::VOTER_PREVIEW_LIMIT].min
    end
  end
end
