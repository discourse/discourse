# frozen_string_literal: true

module DiscourseWorkflows
  class WorkflowVariableSerializer < ApplicationSerializer
    attributes :id, :key, :label, :description, :variable_type, :type_options, :value
  end
end
