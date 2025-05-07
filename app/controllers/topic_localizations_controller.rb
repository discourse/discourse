# frozen_string_literal: true

class TopicLocalizationsController < ApplicationController
  before_action :ensure_logged_in

  def create_or_update
    guardian.ensure_can_localize_content!

    params.require(%i[topic_id locale title])

    if TopicLocalization.exists?(topic_id: params[:topic_id], locale: params[:locale])
      TopicLocalizationUpdater.update(
        topic_id: params[:topic_id],
        locale: params[:locale],
        title: params[:title],
        user: current_user,
      )
      render json: success_json, status: :ok
    else
      TopicLocalizationCreator.create(
        topic_id: params[:topic_id],
        locale: params[:locale],
        title: params[:title],
        user: current_user,
      )
      render json: success_json, status: :created
    end
  end

  def destroy
    guardian.ensure_can_localize_content!

    params.require(%i[topic_id locale])
    TopicLocalizationDestroyer.destroy(
      topic_id: params[:topic_id],
      locale: params[:locale],
      acting_user: current_user,
    )
    head :no_content
  end
end
