# frozen_string_literal: true

class McpOauthAccessToken < ActiveRecord::Base
  belongs_to :authorization,
             class_name: "McpOauthAuthorization",
             foreign_key: :mcp_oauth_authorization_id
  belongs_to :client, class_name: "McpOauthClient", foreign_key: :mcp_oauth_client_id
  belongs_to :user

  scope :usable, -> { where(revoked_at: nil).where("expires_at > ?", Time.zone.now) }

  def self.digest(value)
    Digest::SHA256.hexdigest(value.to_s)
  end

  def self.issue!(authorization:, scopes: authorization.scopes)
    raw = SecureRandom.urlsafe_base64(48)
    create!(
      token_hash: digest(raw),
      authorization: authorization,
      client: authorization.client,
      user: authorization.user,
      resource: authorization.resource,
      scopes: scopes,
      grant_version: authorization.grant_version,
      expires_at: SiteSetting.mcp_access_token_lifetime_minutes.minutes.from_now,
    )
    raw
  end

  def touch_last_used!
    update_column(:last_used_at, Time.zone.now) if last_used_at.nil? || last_used_at < 1.minute.ago
  end
end

# == Schema Information
#
# Table name: mcp_oauth_access_tokens
#
#  id                         :bigint           not null, primary key
#  expires_at                 :datetime         not null
#  grant_version              :integer          not null
#  last_used_at               :datetime
#  resource                   :string           not null
#  revoked_at                 :datetime
#  scopes                     :string           default([]), not null, is an Array
#  token_hash                 :string           not null
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  mcp_oauth_authorization_id :bigint           not null
#  mcp_oauth_client_id        :bigint           not null
#  user_id                    :integer          not null
#
# Indexes
#
#  index_mcp_oauth_access_tokens_on_mcp_oauth_authorization_id  (mcp_oauth_authorization_id)
#  index_mcp_oauth_access_tokens_on_token_hash                  (token_hash) UNIQUE
#  index_mcp_oauth_access_tokens_on_user_id_and_revoked_at      (user_id,revoked_at)
#
