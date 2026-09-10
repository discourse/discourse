# frozen_string_literal: true

module DiscourseWorkflows
  class WorkflowSettingFieldSerializer < ApplicationSerializer
    attributes :id, :key, :label, :description, :field_type, :type_options, :value
  end
end
