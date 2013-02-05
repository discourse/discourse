module Import
  module Adapter
    class RemoveSubTagFromTopics < Base

      register version: '20130116151829', tables: [:topics]

      def up_column_names(table_name, column_names)
        # remove_column :topics, :sub_tag
        if table_name.to_sym == :topics
          column_names.reject {|col| col == 'sub_tag'}
        else
          column_names
        end
      end

      def up_row(table_name, row)
        # remove_column :topics, :sub_tag
        if table_name.to_sym == :topics
          row[0..29] + row[31..-1]
        else
          row
        end
      end

    end
  end
end