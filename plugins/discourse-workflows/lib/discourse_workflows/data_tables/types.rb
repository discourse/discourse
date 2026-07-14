# frozen_string_literal: true

module DiscourseWorkflows
  module DataTables
    module Types
      SYSTEM_COLUMN_TYPE_MAP = {
        "id" => "number",
        "created_at" => "date",
        "updated_at" => "date",
      }.freeze

      SYSTEM_COLUMN_NAMES = SYSTEM_COLUMN_TYPE_MAP.keys.freeze

      def self.system_column?(name)
        SYSTEM_COLUMN_TYPE_MAP.key?(name.to_s)
      end
    end
  end
end
