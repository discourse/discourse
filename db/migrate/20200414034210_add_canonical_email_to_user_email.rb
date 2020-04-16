# frozen_string_literal: true
class AddCanonicalEmailToUserEmail < ActiveRecord::Migration[6.0]
  def change
    add_column :user_emails, :canonical_email, :string, length: 513
    add_index :user_emails, :canonical_email, where: 'canonical_email IS NOT NULL'
  end
end
