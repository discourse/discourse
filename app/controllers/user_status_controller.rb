# frozen_string_literal: true

class UserStatusController < ApplicationController
  requires_login

  def set
    raise Discourse::InvalidParameters.new(:description) if params[:description].blank?

    current_user.set_status(params[:description])
    render json: success_json
  end

  def clear
    current_user.clear_status
    render json: success_json
  end
end
