# frozen_string_literal: true

module DiscourseWorkflows
  module Triggers
    module Manual
      class V1 < Triggers::Base
        def self.identifier
          "trigger:manual"
        end

        def output
          {}
        end
      end
    end
  end
end
