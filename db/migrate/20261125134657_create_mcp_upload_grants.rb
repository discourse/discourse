# frozen_string_literal: true

class CreateMcpUploadGrants < ActiveRecord::Migration[8.1]
  def change
    create_table :mcp_upload_grants do |t|
      t.bigint :upload_id, null: false
      t.bigint :mcp_oauth_authorization_id, null: false
      t.timestamps
    end

    add_index :mcp_upload_grants, %i[mcp_oauth_authorization_id upload_id], unique: true
    add_index :mcp_upload_grants, :upload_id

    create_table :mcp_upload_grant_targets do |t|
      t.bigint :mcp_upload_grant_id, null: false
      t.string :target_type, null: false
      t.bigint :target_id, null: false
      t.timestamps
    end

    add_index :mcp_upload_grant_targets,
              %i[mcp_upload_grant_id target_type target_id],
              unique: true,
              name: "index_mcp_upload_grant_targets_on_grant_and_target"
  end
end
