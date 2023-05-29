# frozen_string_literal: true

class FormTemplatesController < ApplicationController
  requires_login
  before_action :ensure_form_templates_enabled

  def index
    form_templates = FormTemplate.all.order(:id)
    render_serialized(form_templates, FormTemplateSerializer, root: "form_templates")
  end

  def show
    params.require(:id)

    template = FormTemplate.find_by(id: params[:id])
    raise Discourse::NotFound if template.nil?

    render_serialized(template, FormTemplateSerializer, root: "form_template")
  end

  private

  def ensure_form_templates_enabled
    raise Discourse::InvalidAccess.new unless SiteSetting.experimental_form_templates
  end
end
