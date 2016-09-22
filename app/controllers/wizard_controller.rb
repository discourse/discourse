require_dependency 'wizard'
require_dependency 'wizard/builder'

class WizardController < ApplicationController
  before_filter :ensure_wizard_enabled, only: [:index]
  before_filter :ensure_logged_in
  before_filter :ensure_admin

  skip_before_filter :check_xhr, :preload_json

  layout false

  def index
    respond_to do |format|
      format.json do
        wizard = Wizard::Builder.new(current_user).build
        render_serialized(wizard, WizardSerializer)
      end
      format.html {}
    end
  end

  def qunit
  end

end
