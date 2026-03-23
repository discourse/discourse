# frozen_string_literal: true

module DiscourseWorkflows
  class NodeSerializer < ApplicationSerializer
    attributes :id, :type, :type_version, :name, :position, :position_index, :configuration
  end
end
