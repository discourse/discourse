# frozen_string_literal: true

class ClicksController < ApplicationController
  skip_before_action :check_xhr, :verify_authenticity_token

  def track
    params.require(%i[url post_id topic_id])

    TopicLinkClick.create_from(
      url: params[:url],
      post_id: params[:post_id],
      topic_id: params[:topic_id],
      ip: request.remote_ip,
      user_id: current_user&.id,
    )

    render json: success_json
  end
end
