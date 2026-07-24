# frozen_string_literal: true

module DiscourseWorkflows
  class WorkflowView
    attr_reader :id, :name, :active

    def self.from_workflow(workflow, name: nil)
      return new(id: nil, name: name, active: false) if workflow.blank?

      new(id: workflow.id, name: name.presence || workflow.name, active: workflow.published?)
    end

    def initialize(id:, name:, active:)
      @id = id&.to_s
      @name = name.to_s
      @active = !!active
      freeze
    end

    def to_h
      { "id" => id, "name" => name, "active" => active }.compact
    end
  end
end
