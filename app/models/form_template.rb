# frozen_string_literal: true

class FormTemplate < ActiveRecord::Base
  validates :name, presence: true, uniqueness: true, length: { maximum: 100 }
  validates :template, presence: true
end

# == Schema Information
#
# Table name: form_templates
#
#  id         :bigint           not null, primary key
#  name       :string           not null
#  template   :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_form_templates_on_name  (name) UNIQUE
#
