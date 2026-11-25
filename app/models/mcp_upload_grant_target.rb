# frozen_string_literal: true

# A record that an authorization wrote through the MCP server and that
# references one of its granted uploads.
class McpUploadGrantTarget < ActiveRecord::Base
  belongs_to :grant, class_name: "McpUploadGrant", foreign_key: :mcp_upload_grant_id
end

# == Schema Information
#
# Table name: mcp_upload_grant_targets
#
#  id                  :bigint           not null, primary key
#  target_type         :string           not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  mcp_upload_grant_id :bigint           not null
#  target_id           :bigint           not null
#
# Indexes
#
#  index_mcp_upload_grant_targets_on_grant_and_target  (mcp_upload_grant_id,target_type,target_id) UNIQUE
#
