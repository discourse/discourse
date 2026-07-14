# frozen_string_literal: true

module DiscourseWorkflows
  class VariableSerializer < ApplicationSerializer
    attributes :id, :key, :value, :description, :created_by, :created_at, :updated_at

    def created_by
      BasicUserSerializer.new(object.created_by, root: false).as_json
    end
  end
end
