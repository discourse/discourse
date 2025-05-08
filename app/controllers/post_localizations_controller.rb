# frozen_string_literal: true

class PostLocalizationsController < ApplicationController
  before_action :ensure_logged_in

  def create_or_update
    guardian.ensure_can_localize_content!

    params.require(%i[post_id locale raw])

    localization = PostLocalization.find_by(post_id: params[:post_id], locale: params[:locale])
    if localization
      PostLocalizationUpdater.update(
        localization: localization,
        raw: params[:raw],
        user: current_user,
      )
      render json: success_json, status: :ok
    else
      PostLocalizationCreator.create(
        post_id: params[:post_id],
        locale: params[:locale],
        raw: params[:raw],
        user: current_user,
      )
      render json: success_json, status: :created
    end
  end

  def destroy
    guardian.ensure_can_localize_content!

    params.require(%i[post_id locale])
    PostLocalizationDestroyer.destroy(
      post_id: params[:post_id],
      locale: params[:locale],
      acting_user: current_user,
    )
    head :no_content
  end
end
