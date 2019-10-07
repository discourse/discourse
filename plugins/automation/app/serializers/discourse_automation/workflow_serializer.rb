# frozen_string_literal: true

module DiscourseAutomation
  class WorkflowSerializer < ApplicationSerializer
    attributes :id, :name, :trigger, :plans

    def trigger
      TriggerSerializer.new(object.trigger, root: false).as_json
    end

    def plans
      ActiveModel::ArraySerializer.new(object.plans, each_serializer: PlanSerializer, root: false).as_json
    end
  end
end
