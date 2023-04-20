# frozen_string_literal: true

class FormTemplatesController < ApplicationController
  before_action :ensure_form_templates_enabled

  def show
    params.require(:id)
    template = FormTemplate.find(params[:id])
    render_serialized(template, FormTemplateSerializer, root: "form_template")
  end

  private

  def ensure_form_templates_enabled
    raise Discourse::InvalidAccess.new unless SiteSetting.experimental_form_templates
  end
end
