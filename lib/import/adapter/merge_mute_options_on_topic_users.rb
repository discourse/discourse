module Import
  module Adapter
    class MergeMuteOptionsOnTopicUsers < Base

      register version: '20130115012140', tables: [:topic_users]

      def up_column_names(table_name, column_names)
        # rename_column :topic_users, :notifications, :notification_level
        # remove_column :topic_users, :muted_at
        if table_name.to_sym == :topic_users
          column_names.map {|col| col == 'notifications' ? 'notification_level' : col}.reject {|col| col == 'muted_at'}
        else
          column_names
        end
      end

      def up_row(table_name, row)
        # remove_column :topic_users, :muted_at
        if table_name.to_sym == :topic_users
          row[0..6] + row[8..-1]
        else
          row
        end
      end

    end
  end
end
