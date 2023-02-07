# frozen_string_literal: true

class Admin::FormTemplatesController < Admin::StaffController
  before_action :ensure_form_templates_enabled

  def index
    form_templates = FormTemplate.all
    render_serialized(form_templates, FormTemplateSerializer, root: "form_templates")
  end

  def new
  end

  def create
    params.require(:name)
    params.require(:template)

    begin
      template = FormTemplate.create!(name: params[:name], template: params[:template])
      render_serialized(template, FormTemplateSerializer, root: "form_template")
    rescue FormTemplate::NotAllowed => err
      render_json_error(err.message)
    end
  end

  def show
    template = FormTemplate.find(params[:id])
    render_serialized(template, FormTemplateSerializer, root: "form_template")
  end

  def edit
    FormTemplate.find(params[:id])
  end

  def update
    template = FormTemplate.find(params[:id])

    begin
      template = template.update!(name: params[:name], template: params[:template])
      render_serialized(template, FormTemplateSerializer, root: "form_template")
    rescue FormTemplate::NotAllowed => err
      render_json_error(err.message)
    end
  end

  def destroy
    template = FormTemplate.find(params[:id])
    template.destroy!

    render json: success_json
  end

  private

  def ensure_form_templates_enabled
    raise Discourse::InvalidAccess.new unless SiteSetting.experimental_form_templates
  end
end
