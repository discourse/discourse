# frozen_string_literal: true

class FormTemplatesController < ApplicationController
  before_action :ensure_form_templates_enabled

  def show
    params.require(:id)
    templates = FormTemplate.find(params[:id])
    render json: success_json.merge(form_templates: templates || [])
  end

  private

  def ensure_form_templates_enabled
    raise Discourse::InvalidAccess.new unless SiteSetting.experimental_form_templates
  end
end
