# frozen_string_literal: true

module DiscourseWorkflows
  class DataTableColumnSerializer < ApplicationSerializer
    attributes :name, :type

    def name
      object["name"]
    end

    def type
      object["type"]
    end
  end
end
