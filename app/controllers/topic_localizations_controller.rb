# frozen_string_literal: true

class TopicLocalizationsController < ApplicationController
  before_action :ensure_logged_in

  def create_or_update
    topic_id, locale, title = params.require(%i[topic_id locale title])

    guardian.ensure_can_localize_topic!(topic_id)

    topic_localization = TopicLocalization.find_by(topic_id: topic_id, locale: params[:locale])
    if topic_localization
      TopicLocalizationUpdater.update(
        topic_id: topic_id,
        locale: params[:locale],
        title: params[:title],
        user: current_user,
      )
      render json: success_json, status: :ok
    else
      TopicLocalizationCreator.create(topic_id:, locale:, title:, user: current_user)
      render json: success_json, status: :created
    end
  end

  def destroy
    topic_id, locale = params.require(%i[topic_id locale])

    guardian.ensure_can_localize_topic!(topic_id)

    TopicLocalizationDestroyer.destroy(topic_id:, locale:, acting_user: current_user)
    head :no_content
  end
end
