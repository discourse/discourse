# frozen_string_literal: true

class FormTemplatesController < ApplicationController
  include FormTemplateSubmissions

  requires_login
  before_action :ensure_form_templates_enabled, except: :render_output

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

  def render_output
    if params[:post_id].present?
      post = Post.with_deleted.find(params[:post_id])
      guardian.ensure_can_see!(post)
      submission =
        FormTemplate::Submission.for_edit(
          post,
          payload: params.require(:form_template_data),
          guardian:,
          validate: false,
        )
      render json: { raw: submission.render }
    else
      ensure_form_templates_enabled
      render_form_submission(
        category_id: params[:category_id],
        allow_incomplete_answers: true,
      ) { |raw| render json: { raw: } }
    end
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
