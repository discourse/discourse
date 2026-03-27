# frozen_string_literal: true

module DiscourseWorkflows
  module Triggers
    module Error
      class V1 < Triggers::Base
        def self.identifier
          "trigger:error"
        end

        def self.icon
          "triangle-exclamation"
        end

        def self.color_key
          "red"
        end

        def self.output_schema
          {
            execution_id: :integer,
            workflow_id: :integer,
            workflow_name: :string,
            error_message: :string,
            failed_node_name: :string,
          }
        end

        def initialize(error_data = {}, *)
          @error_data = error_data.is_a?(Hash) ? error_data : {}
        end

        def valid?
          true
        end

        def output
          @error_data
        end
      end
    end
  end
end
