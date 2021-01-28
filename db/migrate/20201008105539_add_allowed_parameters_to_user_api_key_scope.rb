# frozen_string_literal: true

class AddAllowedParametersToUserApiKeyScope < ActiveRecord::Migration[6.0]
  def change
    add_column :user_api_key_scopes, :allowed_parameters, :jsonb
  end
end
