# frozen_string_literal: true

class CopyLoginRequiredWelcomeMessage < ActiveRecord::Migration[5.2]
  def change
    execute <<~SQL
      INSERT INTO translation_overrides (locale, translation_key, value, created_at, updated_at)
      SELECT locale, 'login_required.welcome_message_invite_only', value, created_at, updated_at
      FROM translation_overrides
      WHERE translation_key = 'login_required.welcome_message'
      AND NOT EXISTS (SELECT 1 FROM translation_overrides WHERE translation_key = 'login_required.welcome_message_invite_only');
    SQL
  end
end
