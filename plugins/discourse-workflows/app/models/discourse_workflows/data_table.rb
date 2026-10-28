# frozen_string_literal: true

module DiscourseWorkflows
  class DataTable < ActiveRecord::Base
    self.table_name = "discourse_workflows_data_tables"

    VALID_COLUMN_TYPES = %w[string number boolean date].freeze
    MAX_COLUMN_NAME_LENGTH = 63
    COLUMN_NAME_FORMAT = /\A[a-zA-Z_][a-zA-Z0-9_]*\z/

    validates :name,
              presence: true,
              uniqueness: {
                case_sensitive: false,
              },
              length: {
                maximum: 100,
              },
              format: {
                with: /\A[a-zA-Z_][a-zA-Z0-9_ ]*\z/,
              }

    scope :named, ->(names) { where("LOWER(name) IN (?)", Array(names).map(&:downcase)) }

    before_destroy :drop_storage_table

    # Postgres can't reorder physical columns, so the display order lives in `column_order`.
    # User columns sit between `id` and the timestamps; unlisted ones keep their physical order.
    def columns
      system, user =
        DataTables::Storage
          .columns(id)
          .partition { |column| DataTables::Types.system_column?(column["name"]) }
      id_column, *timestamps = system
      user =
        user.sort_by.with_index do |column, index|
          [column_order.index(column["name"]) || column_order.size, index]
        end

      [id_column, *user, *timestamps]
    end

    def user_columns
      columns.reject { |column| DataTables::Types.system_column?(column["name"]) }
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
#  id            :bigint           not null, primary key
#  column_order  :string           default([]), not null, is an Array
#  name          :string(100)      not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  created_by_id :integer
#  updated_by_id :integer
#
# Indexes
#
#  idx_dwf_data_tables_on_created_by_id  (created_by_id)
#  idx_dwf_data_tables_on_lower_name     (lower((name)::text)) UNIQUE
#  idx_dwf_data_tables_on_updated_by_id  (updated_by_id)
#
