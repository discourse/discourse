# frozen_string_literal: true

module DiscourseAutomation
  class TriggerSerializer < ApplicationSerializer
    attributes :id, :workflow_id, :identifier, :options, :triggerable

    def options
      object.options
    end

    def triggerable
      Triggerable[object.identifier]
    end
  end
end
