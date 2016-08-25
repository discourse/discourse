require_dependency 'wizard'

class WizardController < ApplicationController

  before_filter :ensure_logged_in
  before_filter :ensure_staff

  skip_before_filter :check_xhr, :preload_json

  layout false

  def index
    respond_to do |format|
      format.json do
        wizard = Wizard.build
        render_serialized(wizard, WizardSerializer)
      end
      format.html {}
    end
  end

  def qunit
  end

end
