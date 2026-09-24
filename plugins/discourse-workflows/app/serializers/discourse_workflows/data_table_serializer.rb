# frozen_string_literal: true

module DiscourseWorkflows
  class DataTableSerializer < ApplicationSerializer
    attributes :id, :name, :size, :columns, :column_count, :row_count, :created_at, :updated_at

    def column_count
      columns.size
    end

    def row_count
      @options[:table_stats].fetch(object.id).fetch(:row_count)
    end

    def include_row_count?
      @options.key?(:table_stats)
    end

    def columns
      @columns ||= object.columns
    end

    def size
      return @options[:table_stats].fetch(object.id).fetch(:size) if @options[:table_stats]

      DiscourseWorkflows::DataTables::Facade.size_bytes(object.id)
    end
  end
end
