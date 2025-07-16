# frozen_string_literal: true

class DiscourseChatIntegration::PublicController < ApplicationController
  requires_plugin DiscourseChatIntegration::PLUGIN_NAME

  def post_transcript
    params.require(:secret)

    redis_key = "chat_integration:transcript:#{params[:secret]}"
    content = Discourse.redis.get(redis_key)

    if content
      render json: { content: content }
    else
      raise Discourse::NotFound
    end
  end
end
