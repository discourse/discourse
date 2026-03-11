# frozen_string_literal: true

class MarkCategoryApprovalBooleansReadonly < ActiveRecord::Migration[8.0]
  def up
    change_column_default :category_settings, :require_topic_approval, nil
    change_column_default :category_settings, :require_reply_approval, nil

    Migration::ColumnDropper.mark_readonly(:category_settings, :require_topic_approval)
    Migration::ColumnDropper.mark_readonly(:category_settings, :require_reply_approval)
  end

  def down
    Migration::ColumnDropper.drop_readonly(:category_settings, :require_topic_approval)
    Migration::ColumnDropper.drop_readonly(:category_settings, :require_reply_approval)
  end
end
