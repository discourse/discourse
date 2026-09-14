# frozen_string_literal: true

class McpOauthAuthorizationScope < ActiveRecord::Base
  belongs_to :authorization,
             class_name: "McpOauthAuthorization",
             foreign_key: :mcp_oauth_authorization_id,
             inverse_of: :scope_records

  validates :name, presence: true, uniqueness: { scope: :mcp_oauth_authorization_id }
end

# == Schema Information
#
# Table name: mcp_oauth_authorization_scopes
#
#  id                         :bigint           not null, primary key
#  name                       :string           not null
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  mcp_oauth_authorization_id :bigint           not null
#
# Indexes
#
#  idx_mcp_authorization_scopes_unique  (mcp_oauth_authorization_id,name) UNIQUE
#
