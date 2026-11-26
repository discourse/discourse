# frozen_string_literal: true

class CreateAnonymousModeSessions < ActiveRecord::Migration[8.0]
  def change
    # Both IDs come from user_auth_tokens, not new sequences. Ordinary logins
    # need neither a row here nor a backfill.
    create_table :anonymous_mode_sessions, id: :integer, default: nil do |t|
      t.integer :master_user_id, null: false, index: true
      t.references :user_auth_token,
                   type: :integer,
                   null: false,
                   index: {
                     unique: true,
                   },
                   foreign_key: {
                     on_delete: :cascade,
                   }
    end

    # Expiry and session-limit enforcement use delete_all: cleanup of the
    # login and its retired credentials must not depend on model callbacks.
    create_table :retired_user_auth_tokens, id: :integer, default: nil do |t|
      t.references :anonymous_mode_session,
                   type: :integer,
                   null: false,
                   foreign_key: {
                     on_delete: :cascade,
                   }
      t.string :token_hash, null: false, index: { unique: true }
      t.string :previous_token_hash,
               index: {
                 unique: true,
                 where: "previous_token_hash IS NOT NULL",
               }
      t.datetime :rotated_at, null: false, index: true
    end
  end
end
