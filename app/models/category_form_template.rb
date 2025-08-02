# frozen_string_literal: true

class CategoryFormTemplate < ActiveRecord::Base
  belongs_to :category
  belongs_to :form_template
end

# == Schema Information
#
# Table name: category_form_templates
#
#  id               :bigint           not null, primary key
#  category_id      :bigint           not null
#  form_template_id :bigint           not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
# Indexes
#
#  index_category_form_templates_on_category_id       (category_id)
#  index_category_form_templates_on_form_template_id  (form_template_id)
#
