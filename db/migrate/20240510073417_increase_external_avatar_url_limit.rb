# frozen_string_literal: true

class IncreaseExternalAvatarUrlLimit < ActiveRecord::Migration[7.0]
  def change
    change_column :single_sign_on_records, :external_avatar_url, :string, limit: 1500
  end
end
