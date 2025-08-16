# frozen_string_literal: true
class AddImpersonatedUserFieldsToUserAuthToken < ActiveRecord::Migration[8.0]
  def change
    add_column :user_auth_tokens, :impersonated_user_id, :integer
    add_column :user_auth_tokens, :impersonation_expires_at, :datetime
  end
end
