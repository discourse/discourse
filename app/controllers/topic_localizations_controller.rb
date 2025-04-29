# frozen_string_literal: true

class TopicLocalizationsController < ApplicationController
  before_action :ensure_logged_in

  def create
    guardian.ensure_can_localize_content!

    params.require(%i[topic_id locale title])
    TopicLocalizationCreator.create(
      topic_id: params[:topic_id],
      locale: params[:locale],
      title: params[:title],
      user: current_user,
    )
    render json: success_json, status: :created
  end

  def update
    guardian.ensure_can_localize_content!

    params.require(%i[topic_id locale title])
    TopicLocalizationUpdater.update(
      topic_id: params[:topic_id],
      locale: params[:locale],
      title: params[:title],
      user: current_user,
    )
    render json: success_json, status: :ok
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
