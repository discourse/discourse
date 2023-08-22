# frozen_string_literal: true

class FormTemplate < ActiveRecord::Base
  validates :name,
            presence: true,
            uniqueness: true,
            length: {
              maximum: SiteSetting.max_form_template_title_length,
            }
  validates :template,
            presence: true,
            length: {
              maximum: SiteSetting.max_form_template_content_length,
            }
  validates_with FormTemplateYamlValidator

  has_many :category_form_templates, dependent: :destroy
  has_many :categories, through: :category_form_templates
end

# == Schema Information
#
# Table name: form_templates
#
#  id         :bigint           not null, primary key
#  name       :string(100)      not null
#  template   :text             not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_form_templates_on_name  (name) UNIQUE
#
