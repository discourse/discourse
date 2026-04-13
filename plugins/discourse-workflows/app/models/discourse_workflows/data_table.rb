# frozen_string_literal: true

module DiscourseWorkflows
  class DataTable < ActiveRecord::Base
    self.table_name = "discourse_workflows_data_tables"

    validates :name,
              presence: true,
              uniqueness: true,
              length: {
                maximum: 100,
              },
              format: {
                with: /\A[a-zA-Z_][a-zA-Z0-9_ ]*\z/,
              }

    before_destroy :drop_storage_table

    def columns
      DataTables::Storage.columns(id)
    end

    class << self
      def column_name(column)
        column.respond_to?(:name) ? column.name.to_s : column.fetch("name").to_s
      end

      def column_type(column)
        column.respond_to?(:column_type) ? column.column_type.to_s : column.fetch("type").to_s
      end
    end

    private

    def drop_storage_table
      DiscourseWorkflows::DataTables::Facade.drop_table!(id)
    end
  end
end

# == Schema Information
#
# Table name: discourse_workflows_data_tables
#
#  id         :bigint           not null, primary key
#  name       :string(100)      not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_discourse_workflows_data_tables_on_name  (name) UNIQUE
#
