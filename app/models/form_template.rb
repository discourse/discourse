# frozen_string_literal: true

class FormTemplate < ActiveRecord::Base
  validates :name,
            presence: true,
            uniqueness: true,
            length: {
              maximum: -> { SiteSetting.max_form_template_title_length },
            }
  validates :template,
            presence: true,
            length: {
              maximum: -> { SiteSetting.max_form_template_content_length },
            }
  validates_with FormTemplateYamlValidator, if: ->(ft) { ft.template }

  validates :output_template,
            length: {
              maximum: -> { SiteSetting.max_form_template_content_length },
            },
            allow_nil: true
  validate :validate_output_template

  has_many :category_form_templates, dependent: :destroy
  has_many :categories, through: :category_form_templates

  class NotAllowed < StandardError
  end

  class InvalidAnswers < StandardError
  end

  def self.render_submission(payload:, category_id:, guardian:, validate: true)
    raise Discourse::InvalidAccess unless SiteSetting.enable_form_templates
    unless payload.is_a?(String) && payload.bytesize <= 1.megabyte
      raise Discourse::InvalidParameters.new(:form_template_data)
    end

    data = JSON.parse(payload)
    raise Discourse::InvalidParameters.new(:form_template_data) unless data.is_a?(Hash)
    category = Category.find_by(id: category_id)
    unless category && guardian.can_create_topic_on_category?(category)
      raise Discourse::InvalidAccess
    end
    template = category.form_templates.find_by(id: data["id"])
    raise Discourse::NotFound unless template

    template.process!(guardian)
    fields = YAML.safe_load(template.template)
    values =
      FieldValues.new(
        fields:,
        answers: data.fetch("answers"),
        number_formats: data.fetch("number_formats", {}),
      )
    values.validate! if validate
    OutputRenderer.render(values, template.output_template)
  rescue JSON::ParserError, KeyError, ArgumentError
    raise Discourse::InvalidParameters.new(:form_template_data)
  end

  def process!(guardian)
    parsed_template = YAML.safe_load(template)

    tag_group_names = parsed_template.map { |f| f["tag_group"] }.compact.map(&:downcase).uniq

    tag_groups =
      TagGroup
        .includes(:base_tags)
        .visible(guardian)
        .where("lower(name) IN (?)", tag_group_names)
        .index_by { |tg| tg.name }

    parsed_template.map! do |form_field|
      next form_field unless form_field["tag_group"]

      tag_group_name = form_field["tag_group"]
      tags = tag_groups[tag_group_name].base_tags
      ordered_field = {}

      tags =
        tags.sort_by do |t|
          # Transform the name to the displayed value before ordering
          display = t.description.presence || t.name.tr("-", " ").upcase
          display
        end

      form_field.each do |key, value|
        ordered_field[key] = value

        ordered_field["choices"] = tags.map { |t| { "id" => t.id, "name" => t.name } } if key ==
          "id"
      end

      ordered_field["attributes"] ||= {}
      ordered_field["attributes"]["tag_group"] = tag_group_name
      translated_tags = tags.select { |t| t.description }.to_h { |t| [t.name, t.description] }
      ordered_field["attributes"]["tag_choices"] = translated_tags

      ordered_field
    end

    self.template = YAML.dump(parsed_template)
    self
  end

  private

  def validate_output_template
    OutputRenderer.parse(output_template) if output_template.present?
  rescue Liquid::Error
    errors.add(:output_template, I18n.t("form_templates.errors.invalid_output_template"))
  end
end

# == Schema Information
#
# Table name: form_templates
#
#  id              :bigint           not null, primary key
#  name            :string           not null
#  output_template :text
#  template        :text             not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_form_templates_on_name  (name) UNIQUE
#
