# frozen_string_literal: true

class McpOauthAuthorizationCode < ActiveRecord::Base
  belongs_to :authorization,
             class_name: "McpOauthAuthorization",
             foreign_key: :mcp_oauth_authorization_id

  validates :code_hash, presence: true, uniqueness: true
  validates :code_challenge, :redirect_uri, :resource, presence: true

  scope :usable, -> { where(consumed_at: nil).where("expires_at > ?", Time.zone.now) }

  def self.digest(value)
    Digest::SHA256.hexdigest(value.to_s)
  end

  def self.issue!(authorization:, redirect_uri:, resource:, code_challenge:)
    raw = SecureRandom.urlsafe_base64(48)
    create!(
      code_hash: digest(raw),
      authorization: authorization,
      redirect_uri: redirect_uri,
      resource: resource,
      code_challenge: code_challenge,
      scopes: authorization.scopes,
      grant_version: authorization.grant_version,
      expires_at: SiteSetting.mcp_authorization_code_lifetime_seconds.seconds.from_now,
    )
    raw
  end
end

# == Schema Information
#
# Table name: mcp_oauth_authorization_codes
#
#  id                         :bigint           not null, primary key
#  code_challenge             :string           not null
#  code_challenge_method      :string           default("S256"), not null
#  code_hash                  :string           not null
#  consumed_at                :datetime
#  expires_at                 :datetime         not null
#  grant_version              :integer          not null
#  redirect_uri               :string           not null
#  resource                   :string           not null
#  scopes                     :string           default([]), not null, is an Array
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  mcp_oauth_authorization_id :bigint           not null
#
# Indexes
#
#  idx_on_mcp_oauth_authorization_id_d749d8a9de      (mcp_oauth_authorization_id)
#  index_mcp_oauth_authorization_codes_on_code_hash  (code_hash) UNIQUE
#
