# frozen_string_literal: true

class AddIndexOnUserIdToSingleSignOnRecords < ActiveRecord::Migration[5.2]
  def change
    add_index :single_sign_on_records, :user_id
  end
end
