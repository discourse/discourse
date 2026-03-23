# frozen_string_literal: true

module DiscourseWorkflows
  class ConnectionSerializer < ApplicationSerializer
    attributes :id, :source_node_id, :target_node_id, :source_output, :target_input
  end
end
