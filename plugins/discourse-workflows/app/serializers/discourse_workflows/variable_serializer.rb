# frozen_string_literal: true

module DiscourseWorkflows
  class VariableSerializer < ApplicationSerializer
    attributes :id, :key, :value, :description, :created_at, :updated_at
  end
end
