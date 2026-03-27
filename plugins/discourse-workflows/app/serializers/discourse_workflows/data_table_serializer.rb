# frozen_string_literal: true

module DiscourseWorkflows
  class DataTableSerializer < ApplicationSerializer
    attributes :id, :name, :row_count, :created_at, :updated_at

    has_many :columns, serializer: DiscourseWorkflows::DataTableColumnSerializer, embed: :objects

    def row_count
      DiscourseWorkflows::DataTableRowsRepository.count_for(object)
    end
  end
end
