# frozen_string_literal: true

class Admin::FormTemplatesController < Admin::StaffController
  def index
    form_templates = FormTemplate.all
    render_serialized(form_templates, FormTemplateSerializer, root: "form_templates")
  end

  def new
  end

  def create
    params.require(:name)
    params.require(:template)

    template = FormTemplate.new(name: params[:name], template: params[:template])

    if template.save
      render_serialized(template, FormTemplateSerializer, root: "form_template")
    else
      render_json_error(template)
    end
  end

  def show
    template = FormTemplate.find(params[:id])
    render_serialized(template, FormTemplateSerializer, root: "form_template")
  end
end
