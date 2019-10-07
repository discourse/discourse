# frozen_string_literal: true

module DiscourseAutomation
  class PlanSerializer < ApplicationSerializer
    attributes :id, :workflow_id, :delay, :identifier, :options, :plannable

    def options
      object.options
    end

    def delay
      object.delay
    end

    def plannable
      Plannable[object.identifier]
    end
  end
end
