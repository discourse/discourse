# frozen_string_literal: true

class TopicLocalizationsController < ApplicationController
  before_action :ensure_logged_in

  def create_or_update
    topic_id, locale, title = params.require(%i[topic_id locale title])

    topic = Topic.find_by(id: topic_id)
    raise Discourse::NotFound unless topic

    guardian.ensure_can_localize_topic!(topic)

    topic_localization = TopicLocalization.find_by(topic_id: topic.id, locale: params[:locale])
    if topic_localization
      TopicLocalizationUpdater.update(
        topic:,
        locale: params[:locale],
        title: params[:title],
        user: current_user,
      )
      render json: success_json, status: :ok
    else
      TopicLocalizationCreator.create(topic:, locale:, title:, user: current_user)
      render json: success_json, status: :created
    end
  end

  def destroy
    topic_id, locale = params.require(%i[topic_id locale])

    topic = Topic.find_by(id: topic_id)
    raise Discourse::NotFound unless topic

    guardian.ensure_can_localize_topic!(topic)

    TopicLocalizationDestroyer.destroy(topic:, locale:, acting_user: current_user)
    head :no_content
  end
end
