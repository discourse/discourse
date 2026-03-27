# frozen_string_literal: true

module DiscourseWorkflows
  class DataTableSerializer < ApplicationSerializer
    attributes :id, :name, :size, :created_at, :updated_at

    has_many :columns, serializer: DiscourseWorkflows::DataTableColumnSerializer, embed: :objects

    def size
      if @options[:table_sizes]
        @options[:table_sizes].fetch(object.id, 0)
      else
        DiscourseWorkflows::DataTableStorage.size_bytes(object.id)
      end
    end
  end
end
