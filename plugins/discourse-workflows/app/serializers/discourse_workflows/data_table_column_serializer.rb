# frozen_string_literal: true

module DiscourseWorkflows
  class DataTableColumnSerializer < ApplicationSerializer
    attributes :id, :name, :type, :position
  end
end
