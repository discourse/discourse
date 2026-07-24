# frozen_string_literal: true

module DiscourseWorkflows
  class WorkflowVersionSerializer < ApplicationSerializer
    attributes :version_id, :version_number, :name, :autosaved, :created_at, :is_current, :is_active

    attribute :created_by

    def created_by
      BasicUserSerializer.new(object.created_by, root: false).as_json
    end

    def is_current
      @options[:current_version_id] == object.version_id
    end

    def is_active
      @options[:active_version_id] == object.version_id
    end
  end
end
