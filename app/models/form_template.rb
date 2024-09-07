# frozen_string_literal: true

class FormTemplate < ActiveRecord::Base
  validates :name, presence: true, uniqueness: true
  validates :template, presence: true
  validates_with FormTemplateYamlValidator

  has_many :category_form_templates, dependent: :destroy
  has_many :categories, through: :category_form_templates

  class NotAllowed < StandardError
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
