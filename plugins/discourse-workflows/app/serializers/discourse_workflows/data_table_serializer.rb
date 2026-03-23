# frozen_string_literal: true

module DiscourseWorkflows
  class DataTableSerializer < ApplicationSerializer
    attributes :id, :name, :columns, :row_count, :created_at, :updated_at

    def row_count
      DiscourseWorkflows::DataTableRowsRepository.count_for(object)
    end
  end
end
