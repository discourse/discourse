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

    tag_group_names = parsed_template.map { |f| f["tag_group"] }.compact.map(&:downcase).uniq

    tag_groups =
      TagGroup
        .includes(:tags)
        .visible(guardian)
        .where("lower(name) IN (?)", tag_group_names)
        .index_by { |tg| tg.name }

    parsed_template.map! do |form_field|
      next form_field unless form_field["tag_group"]

      tag_group_name = form_field["tag_group"]
      tags = tag_groups[tag_group_name].tags.reject { |tag| tag.target_tag_id.present? }
      ordered_field = {}

      tags =
        tags.sort_by do |t|
          # Transform the name to the displayed value before ordering
          display = t.description.presence || t.name.tr("-", " ").upcase
          display
        end

      form_field.each do |key, value|
        ordered_field[key] = value

        ordered_field["choices"] = tags.map(&:name) if key == "id"
        if key == "attributes"
          ordered_field["attributes"]["tag_group"] = tag_group_name
          translated_tags = tags.select { |t| t.description }.to_h { |t| [t.name, t.description] }
          ordered_field["attributes"]["tag_choices"] = translated_tags
        end
      end

      ordered_field
    end

    YAML.dump(parsed_template)
  end
end
