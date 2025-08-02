# frozen_string_literal: true

class AddIndexReplyIdOnPostReplies < ActiveRecord::Migration[5.2]
  def change
    add_index :post_replies, :reply_id
  end
end
