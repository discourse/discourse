# frozen_string_literal: true

class AddBulkPermanentTopicDeletionToUserOptions < ActiveRecord::Migration[8.0]
  def change
    add_column :user_options, :bulk_permanent_topic_deletion, :boolean, default: false, null: false
  end
end
