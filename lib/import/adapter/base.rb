module Import
  module Adapter
    class Base

      def self.register(opts={})
        Import.add_import_adapter self, opts[:version], opts[:tables]
        @table_names = opts[:tables]
      end

      def apply_to_column_names(table_name, column_names)
        up_column_names(table_name, column_names)
      end

      def apply_to_row(table_name, row)
        up_row(table_name, row)
      end


      # Implement the following methods in subclasses:

      def up_column_names(table_name, column_names)
        column_names
      end

      def up_row(table_name, row)
        row
      end

    end
  end
end