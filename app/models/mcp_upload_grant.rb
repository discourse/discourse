# frozen_string_literal: true

# An upload that an OAuth authorization created through the MCP server. While
# a content rule is active, agents may only reference uploads granted to their
# authorization, and only while every record that references the upload is one
# the same authorization wrote.
class McpUploadGrant < ActiveRecord::Base
  belongs_to :upload
  belongs_to :authorization,
             class_name: "McpOauthAuthorization",
             foreign_key: :mcp_oauth_authorization_id
  has_many :targets, class_name: "McpUploadGrantTarget", dependent: :delete_all
end

# == Schema Information
#
# Table name: mcp_upload_grants
#
#  id                         :bigint           not null, primary key
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  mcp_oauth_authorization_id :bigint           not null
#  upload_id                  :bigint           not null
#
# Indexes
#
#  idx_on_mcp_oauth_authorization_id_upload_id_e1afc85612  (mcp_oauth_authorization_id,upload_id) UNIQUE
#  index_mcp_upload_grants_on_upload_id                    (upload_id)
#
