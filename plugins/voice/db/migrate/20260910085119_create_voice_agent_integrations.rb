# frozen_string_literal: true
class CreateVoiceAgentIntegrations < ActiveRecord::Migration[8.0]
  def change
    create_table :voice_agent_integrations do |t|
      t.string :name, null: false
      t.bigint :bot_user_id, null: false
      t.string :credential_digest, null: false
      t.integer :role, null: false, default: 0
      t.datetime :revoked_at
      t.timestamps
    end

    create_table :voice_agent_integration_rooms do |t|
      t.bigint :agent_integration_id, null: false
      t.bigint :room_id, null: false
      t.timestamps
    end

    create_table :voice_agent_exclusions do |t|
      t.bigint :agent_integration_id, null: false
      t.bigint :room_id, null: false
      t.datetime :expires_at
      t.timestamps
    end

    add_index :voice_agent_integrations, :bot_user_id, unique: true
    add_index :voice_agent_integrations, :credential_digest, unique: true
    add_index :voice_agent_integration_rooms,
              %i[agent_integration_id room_id],
              unique: true,
              name: "idx_voice_agent_integration_rooms_unique"
    add_index :voice_agent_integration_rooms, :room_id
    add_index :voice_agent_exclusions,
              %i[agent_integration_id room_id],
              unique: true,
              name: "idx_voice_agent_exclusions_unique"
    add_index :voice_agent_exclusions, :expires_at
  end
end
