# frozen_string_literal: true

module DiscourseWorkflows
  class Variable < ActiveRecord::Base
    self.table_name = "discourse_workflows_variables"

    validates :key,
              presence: true,
              uniqueness: true,
              length: {
                maximum: 100,
              },
              format: {
                with: /\A[a-zA-Z_][a-zA-Z0-9_]*\z/,
              }
    validates :value, length: { maximum: 1000 }
  end
end

# == Schema Information
#
# Table name: discourse_workflows_variables
#
#  id          :bigint           not null, primary key
#  description :text
#  key         :string(100)      not null
#  value       :string(1000)     default(""), not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_discourse_workflows_variables_on_key  (key) UNIQUE
#
