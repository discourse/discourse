# frozen_string_literal: true

module DiscourseWorkflows
  class DataTable < ActiveRecord::Base
    self.table_name = "discourse_workflows_data_tables"
    self.ignored_columns = %w[columns description]

    validates :name,
              presence: true,
              uniqueness: true,
              length: {
                maximum: 100,
              },
              format: {
                with: /\A[a-zA-Z_][a-zA-Z0-9_ ]*\z/,
              }

    has_many :columns,
             -> { order(:position) },
             class_name: "DiscourseWorkflows::DataTableColumn",
             inverse_of: :data_table,
             validate: true,
             dependent: :destroy

    validate :validate_column_set

    before_destroy :drop_storage_table

    class << self
      def column_name(column)
        if column.is_a?(DiscourseWorkflows::DataTableColumn)
          column.name.to_s
        else
          DiscourseWorkflows::DataTableColumn.definition_name(column)
        end
      end

      def column_type(column)
        if column.is_a?(DiscourseWorkflows::DataTableColumn)
          column.column_type.to_s
        else
          DiscourseWorkflows::DataTableColumn.definition_type(column)
        end
      end
    end

    def storage_table_name
      DiscourseWorkflows::DataTableStorage.table_name(id)
    end

    def column_by_id!(column_id)
      columns.find(column_id)
    end

    def column_map_by_id
      columns.index_by { |column| column.id.to_s }
    end

    def column_map_by_name
      columns.index_by(&:name)
    end

    def next_column_position
      columns.size
    end

    def reorder_columns!(ordered_columns)
      ordered_columns = ordered_columns.to_a

      if ordered_columns.size != columns.size ||
           ordered_columns.any? { |column| column.data_table_id != id }
        raise ArgumentError, "Ordered columns must match the data table column set"
      end

      ordered_columns.each_with_index do |column, index|
        column.update_columns(position: index + ordered_columns.size)
      end

      ordered_columns.each_with_index { |column, index| column.update_columns(position: index) }
    end

    private

    def drop_storage_table
      DiscourseWorkflows::DataTableStorage.drop_table!(id)
    end

    def validate_column_set
      validate_duplicate_column_attribute(:name, "must be unique")
      validate_duplicate_column_attribute(:position, "must be unique")
    end

    def validate_duplicate_column_attribute(attribute, message)
      values =
        columns
          .reject(&:marked_for_destruction?)
          .map { |column| column.public_send(attribute) }
          .compact
      duplicate = values.find { |value| values.count(value) > 1 }
      errors.add(:columns, "#{attribute} #{message}") if duplicate.present?
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
