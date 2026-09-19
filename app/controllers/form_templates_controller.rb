# frozen_string_literal: true

class FormTemplatesController < ApplicationController
  requires_login
  before_action :ensure_form_templates_enabled

  def index
    form_templates = accessible_form_templates.order(:id)
    render_serialized(form_templates, FormTemplateSerializer, root: "form_templates")
  end

  def show
    params.require(:id)

    template = accessible_form_templates.find_by(id: params[:id])

    raise Discourse::NotFound if template.nil?

    template.process!(guardian)

    render_serialized(template, FormTemplateSerializer, root: "form_template")
  end

  private

  def accessible_form_templates
    unassigned = FormTemplate.where.not(id: CategoryFormTemplate.select(:form_template_id))
    accessible =
      FormTemplate.where(
        id:
          CategoryFormTemplate.where(category_id: Category.secured(guardian)).select(
            :form_template_id,
          ),
      )
    unassigned.or(accessible)
  end

  def ensure_form_templates_enabled
    raise Discourse::InvalidAccess.new unless SiteSetting.enable_form_templates
  end
end
