# frozen_string_literal: true

module DiscourseWorkflows
  class NodeSerializer < ApplicationSerializer
    attributes :id, :type, :name, :position, :position_index, :configuration
  end
end
