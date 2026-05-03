# frozen_string_literal: true

module DiscourseWorkflows
  class CurrentExecution < ActiveSupport::CurrentAttributes
    attribute :workflow_execution_chains
  end
end
