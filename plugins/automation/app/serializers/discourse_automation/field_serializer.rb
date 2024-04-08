# frozen_string_literal: true

module DiscourseAutomation
  class FieldSerializer < ApplicationSerializer
    attributes :id, :component, :name, :metadata, :is_required

    def metadata
      object.metadata || {}
    end

    def is_required
      object.template&.dig(:required)
    end
  end
end
