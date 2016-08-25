require_dependency 'wizard'
require_dependency 'wizard/step_updater'

class StepsController < ApplicationController

  before_filter :ensure_logged_in
  before_filter :ensure_staff

  def update
    updater = Wizard::StepUpdater.new(current_user, params[:id])
    updater.update(params[:fields])
    render nothing: true
  end

end
