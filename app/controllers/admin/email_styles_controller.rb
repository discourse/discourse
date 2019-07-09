# frozen_string_literal: true

class Admin::EmailStylesController < Admin::AdminController
  def show
    render_serialized(EmailStyle.new, EmailStyleSerializer)
  end

  def update
    updater = EmailStyleUpdater.new(current_user)
    if updater.update(params.permit(:html, :css))
      render json: success_json
    else
      render_json_error(updater.errors, status: 422)
    end
  end
end
