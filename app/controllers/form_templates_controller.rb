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

    template.template = process_template(template.template)

    render_serialized(template, FormTemplateSerializer, root: "form_template")
  end

  private

  def ensure_form_templates_enabled
    raise Discourse::InvalidAccess.new unless SiteSetting.experimental_form_templates
  end

  def process_template(template_content)
    parsed_template = YAML.safe_load(template_content)

    parsed_template.map! do |form_field|
      next form_field unless form_field["tag_group"]

      tag_group_name = form_field["tag_group"]

      tags =
        TagGroup
          .includes(:tags)
          .visible(guardian)
          .all
          .where("lower(NAME) in (?)", tag_group_name.downcase)

      ordered_field = {}

      form_field.each do |key, value|
        ordered_field[key] = value
        if key == "id"
          ordered_field["choices"] = tags.first.tags.map(&:name)
          translated_tags =
            tags.first.tags.select { |t| t.description }.to_h { |t| [t.name, t.description] }
          ordered_field["tag_translations"] = translated_tags
        end
      end

      ordered_field
    end

    YAML.dump(parsed_template)
  end
end
