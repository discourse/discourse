# frozen_string_literal: true

class InlineOneboxController < ApplicationController
  requires_login

  def show
    hijack do
      oneboxes = InlineOneboxer.new(
        params[:urls] || [],
        user_id: current_user.id,
        category_id: params[:category_id].to_i,
        topic_id: params[:topic_id].to_i
      ).process
      render json: { "inline-oneboxes" => oneboxes }
    end
  end
end
