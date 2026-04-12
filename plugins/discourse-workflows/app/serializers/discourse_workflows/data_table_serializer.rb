# frozen_string_literal: true

module DiscourseWorkflows
  class DataTableSerializer < ApplicationSerializer
    attributes :id, :name, :size, :columns, :created_at, :updated_at

    def columns
      object.columns.map { |c| { name: c["name"], type: c["type"] } }
    end

    def size
      if @options[:table_sizes]
        @options[:table_sizes].fetch(object.id, 0)
      else
        DiscourseWorkflows::DataTables::Facade.size_bytes(object.id)
      end
    end
  end
end
