# frozen_string_literal: true

module DiscourseWorkflows
  class WorkflowTagSerializer < ApplicationSerializer
    attributes :id, :name, :workflow_count

    def workflow_count
      object.attributes["workflow_count_value"].to_i
    end
  end
end
