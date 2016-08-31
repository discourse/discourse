require_dependency 'wizard'
require_dependency 'wizard/step_updater'

class StepsController < ApplicationController

  before_filter :ensure_logged_in
  before_filter :ensure_staff

  def update
    updater = Wizard::StepUpdater.new(current_user, params[:id])
    updater.update(params[:fields])

    if updater.success?
      render json: success_json
    else
      errors = []
      updater.errors.messages.each do |field, msg|
        errors << {field: field, description: msg.join }
      end
      render json: { errors: errors }, status: 422
    end
  end

end
