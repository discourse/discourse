class Wizard::WizardController < ApplicationController

  before_filter :ensure_logged_in
  before_filter :ensure_staff

  skip_before_filter :check_xhr, :preload_json

  layout false

  def index
  end

  def qunit
  end

end
