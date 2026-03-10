# frozen_string_literal: true

class AddApprovalTypeColumnsToCategorySettings < ActiveRecord::Migration[8.0]
  def up
    add_column :category_settings, :topic_approval_type, :integer, null: false, default: 0
    add_column :category_settings, :reply_approval_type, :integer, null: false, default: 0

    execute(<<~SQL)
      UPDATE category_settings
      SET topic_approval_type = CASE WHEN require_topic_approval = true THEN 1 ELSE 0 END,
          reply_approval_type = CASE WHEN require_reply_approval = true THEN 1 ELSE 0 END
    SQL
  end

  def down
    remove_column :category_settings, :topic_approval_type
    remove_column :category_settings, :reply_approval_type
  end
end
