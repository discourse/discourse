class RenameExpressionColumnsInForumThread < ActiveRecord::Migration
  def change
    rename_column 'forum_threads', 'expression1_count', 'off_topic_count'
    rename_column 'forum_threads', 'expression2_count', 'offensive_count'
    rename_column 'forum_threads', 'expression3_count', 'like_count'
    remove_column 'forum_threads', 'expression4_count'
    remove_column 'forum_threads', 'expression5_count'

  end
end
