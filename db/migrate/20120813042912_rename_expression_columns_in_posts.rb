class RenameExpressionColumnsInPosts < ActiveRecord::Migration[4.2]
  def change
    rename_column 'posts', 'expression1_count', 'off_topic_count'
    rename_column 'posts', 'expression2_count', 'offensive_count'
    rename_column 'posts', 'expression3_count', 'like_count'
    remove_column 'posts', 'expression4_count'
    remove_column 'posts', 'expression5_count'
  end
end
