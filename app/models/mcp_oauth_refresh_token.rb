# frozen_string_literal: true

class McpOauthRefreshToken < ActiveRecord::Base
  belongs_to :authorization,
             class_name: "McpOauthAuthorization",
             foreign_key: :mcp_oauth_authorization_id

  scope :usable,
        -> { where(consumed_at: nil, revoked_at: nil).where("expires_at > ?", Time.zone.now) }

  def self.digest(value)
    Digest::SHA256.hexdigest(value.to_s)
  end

  def self.issue!(
    authorization:,
    scopes: authorization.scopes,
    family_id: SecureRandom.uuid,
    parent: nil
  )
    raw = SecureRandom.urlsafe_base64(64)
    token =
      create!(
        token_hash: digest(raw),
        family_id: family_id,
        authorization: authorization,
        parent_id: parent&.id,
        scopes: scopes,
        grant_version: authorization.grant_version,
        expires_at: parent&.expires_at || SiteSetting.mcp_refresh_token_lifetime_days.days.from_now,
      )
    parent&.update!(replacement_id: token.id, consumed_at: Time.zone.now)
    [raw, token]
  end

  def revoke_family!
    self.class.where(family_id: family_id, revoked_at: nil).update_all(revoked_at: Time.zone.now)
  end
end

# == Schema Information
#
# Table name: mcp_oauth_refresh_tokens
#
#  id                         :bigint           not null, primary key
#  consumed_at                :datetime
#  expires_at                 :datetime         not null
#  grant_version              :integer          not null
#  revoked_at                 :datetime
#  scopes                     :string           default([]), not null, is an Array
#  token_hash                 :string           not null
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  family_id                  :string           not null
#  mcp_oauth_authorization_id :bigint           not null
#  parent_id                  :bigint
#  replacement_id             :bigint
#
# Indexes
#
#  index_mcp_oauth_refresh_tokens_on_family_id                   (family_id)
#  index_mcp_oauth_refresh_tokens_on_mcp_oauth_authorization_id  (mcp_oauth_authorization_id)
#  index_mcp_oauth_refresh_tokens_on_token_hash                  (token_hash) UNIQUE
#
