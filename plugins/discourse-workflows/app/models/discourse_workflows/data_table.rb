# frozen_string_literal: true

module DiscourseWorkflows
  class DataTable < ActiveRecord::Base
    self.table_name = "discourse_workflows_data_tables"
    self.ignored_columns = ["description"]

    VALID_COLUMN_TYPES = %w[string number boolean date].freeze
    RESERVED_COLUMN_NAMES = %w[id created_at updated_at].freeze
    MAX_COLUMN_NAME_LENGTH = 63

    validates :name,
              presence: true,
              uniqueness: true,
              length: {
                maximum: 100,
              },
              format: {
                with: /\A[a-zA-Z_][a-zA-Z0-9_ ]*\z/,
              }

    before_validation :normalize_columns_attribute
    validate :validate_columns
    after_create :create_storage_table
    before_update :sync_storage_columns, if: :will_save_change_to_columns?
    before_destroy :drop_storage_table

    class << self
      def normalize_columns(columns)
        return [] if columns.nil?
        return columns unless columns.is_a?(Array)

        columns.map { |column| normalize_column(column) }
      end

      def normalize_column(column)
        return column unless column.respond_to?(:to_h)

        column.to_h.deep_stringify_keys
      end

      def column_name(column)
        column&.dig("name").to_s
      end

      def column_type(column)
        column&.dig("type").to_s
      end
    end

    def storage_table_name
      DiscourseWorkflows::DataTableStorage.table_name(id)
    end

    def columns
      self.class.normalize_columns(self[:columns])
    end

    private

    def create_storage_table
      DiscourseWorkflows::DataTableStorage.create_table!(self)
    end

    def sync_storage_columns
      previous_columns = self.class.normalize_columns(changes_to_save["columns"]&.first)
      DiscourseWorkflows::DataTableStorage.sync_columns!(self, previous_columns: previous_columns)
    end

    def drop_storage_table
      DiscourseWorkflows::DataTableStorage.drop_table!(id)
    end

    def normalize_columns_attribute
      self[:columns] = self.class.normalize_columns(self[:columns]) if self[:columns].is_a?(Array)
    end

    def validate_columns
      return if columns.blank?

      unless columns.is_a?(Array)
        errors.add(:columns, "must be an array")
        return
      end

      seen_names = Set.new

      columns.each do |col|
        name = self.class.column_name(col)
        type = self.class.column_type(col)

        if name.blank?
          errors.add(:columns, "column name cannot be blank")
          next
        end

        if name.length > MAX_COLUMN_NAME_LENGTH
          errors.add(:columns, "column name '#{name}' exceeds #{MAX_COLUMN_NAME_LENGTH} characters")
        end

        unless name.match?(/\A[a-zA-Z_][a-zA-Z0-9_]*\z/)
          errors.add(
            :columns,
            "column name '#{name}' must start with a letter or underscore and contain only letters, numbers, and underscores",
          )
        end

        if RESERVED_COLUMN_NAMES.include?(name)
          errors.add(:columns, "column name '#{name}' is reserved")
        end

        errors.add(:columns, "duplicate column name '#{name}'") if seen_names.include?(name)
        seen_names << name

        if VALID_COLUMN_TYPES.exclude?(type)
          errors.add(
            :columns,
            "column '#{name}' has invalid type '#{type}' (must be one of: #{VALID_COLUMN_TYPES.join(", ")})",
          )
        end
      end
    end
  end
end

# == Schema Information
#
# Table name: discourse_workflows_data_tables
#
#  id         :bigint           not null, primary key
#  columns    :jsonb            not null
#  name       :string(100)      not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_discourse_workflows_data_tables_on_name  (name) UNIQUE
#
