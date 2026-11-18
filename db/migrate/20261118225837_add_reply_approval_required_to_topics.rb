# frozen_string_literal: true

class AddReplyApprovalRequiredToTopics < ActiveRecord::Migration[8.0]
  def change
    add_column :topics, :reply_approval_required, :boolean, default: false, null: false
  end
end
