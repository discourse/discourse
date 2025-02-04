# frozen_string_literal: true
class IncreaseExternalAvatarUrlLimitTo2000 < ActiveRecord::Migration[7.1]
  def change
    change_column :single_sign_on_records, :external_avatar_url, :string, limit: 2000
  end
end
