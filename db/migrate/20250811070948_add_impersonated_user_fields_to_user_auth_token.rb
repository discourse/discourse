# frozen_string_literal: true
class AddImpersonatedUserFieldsToUserAuthToken < ActiveRecord::Migration[8.0]
  def change
    add_column :user_auth_tokens, :impersonated_user_id, :integer
    add_column :user_auth_tokens, :impersonation_expires_at, :datetime

    add_index :user_auth_tokens,
              %i[impersonation_expires_at],
              where: "impersonation_expires_at IS NOT NULL"
  end
end
