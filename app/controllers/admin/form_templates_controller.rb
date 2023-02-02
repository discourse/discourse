# frozen_string_literal: true

class Admin::FormTemplatesController < Admin::StaffController
  def index
    form_templates = FormTemplate.all
    render_serialized(form_templates, FormTemplateSerializer, root: "form_templates")
  end
end
