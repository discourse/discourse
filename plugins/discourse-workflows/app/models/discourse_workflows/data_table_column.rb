# frozen_string_literal: true

module DiscourseWorkflows
  class DataTableColumn < ActiveRecord::Base
    self.table_name = "discourse_workflows_data_table_columns"

    VALID_COLUMN_TYPES = %w[string number boolean date].freeze
    RESERVED_COLUMN_NAMES = %w[id created_at updated_at].freeze
    MAX_COLUMN_NAME_LENGTH = 63

    belongs_to :data_table, class_name: "DiscourseWorkflows::DataTable", inverse_of: :columns

    validates :name,
              presence: true,
              length: {
                maximum: MAX_COLUMN_NAME_LENGTH,
              },
              format: {
                with: /\A[a-zA-Z_][a-zA-Z0-9_]*\z/,
                message:
                  "must start with a letter or underscore and contain only letters, numbers, and underscores",
              },
              exclusion: {
                in: RESERVED_COLUMN_NAMES,
                message: "is reserved",
              }
    validates :column_type, presence: true, inclusion: { in: VALID_COLUMN_TYPES }
    validates :position,
              presence: true,
              numericality: {
                only_integer: true,
                greater_than_or_equal_to: 0,
              }
    validates :name, uniqueness: { scope: :data_table_id }
    validates :position, uniqueness: { scope: :data_table_id }

    class << self
      def normalize_definition(column)
        return column unless column.respond_to?(:to_h)

        column.to_h.deep_stringify_keys
      end

      def definition_name(column)
        normalize_definition(column)&.dig("name").to_s
      end

      def definition_type(column)
        normalize_definition(column)&.dig("type").to_s
      end
    end

    def type
      column_type
    end
  end
end

# == Schema Information
#
# Table name: discourse_workflows_data_table_columns
#
#  id            :bigint           not null, primary key
#  column_type   :string(20)       not null
#  data_table_id :bigint           not null
#  name          :string(63)       not null
#  position      :integer          not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  index_discourse_workflows_data_table_columns_on_data_table_id               (data_table_id)
#  index_discourse_workflows_data_table_columns_on_data_table_id_and_name      (data_table_id,name) UNIQUE
#  index_discourse_workflows_data_table_columns_on_data_table_id_and_position  (data_table_id,position) UNIQUE
#
