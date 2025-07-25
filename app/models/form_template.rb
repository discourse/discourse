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

  has_many :category_form_templates, dependent: :destroy
  has_many :categories, through: :category_form_templates

  class NotAllowed < StandardError
  end

  def process!(guardian)
    parsed_template = YAML.safe_load(template)

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
end

# == Schema Information
#
# Table name: form_templates
#
#  id         :bigint           not null, primary key
#  name       :string           not null
#  template   :text             not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_form_templates_on_name  (name) UNIQUE
#
