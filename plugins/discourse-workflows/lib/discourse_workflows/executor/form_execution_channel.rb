# frozen_string_literal: true

module DiscourseWorkflows
  class Executor
    module FormExecutionChannel
      extend ActiveSupport::Concern

      class_methods do
        def form_channel(execution_id, token)
          "/discourse-workflows/form-execution/#{execution_id}-#{token}"
        end
      end
    end
  end
end
