# frozen_string_literal: true

module DiscourseAutomation
  class TriggerSerializer < ApplicationSerializer
    attributes :id, :name, :metadata

    def metadata
      ((options[:trigger_metadata] || {}).stringify_keys).merge(object.metadata || {})
    end
  end
end
