# frozen_string_literal: true

class WizardController < ApplicationController
  requires_login

  before_action :ensure_admin
  before_action :ensure_wizard_enabled

  def index
    respond_to do |format|
      format.json do
        wizard = Wizard::Builder.new(current_user).build
        render_serialized(wizard, WizardSerializer)
      end

      format.html { render body: nil }
    end
  end
end
