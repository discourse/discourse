# frozen_string_literal: true

module DiscourseWorkflows
  class Executor
    module FormExecutionChannel
      extend ActiveSupport::Concern

      class_methods do
        def form_channel(execution_id)
          token = HmacSigner.sign("form_execution:#{execution_id}")
          "/discourse-workflows/form-execution/#{execution_id}-#{token}"
        end
      end
    end
  end
end
