# frozen_string_literal: true

class McpOauthAuthorization < ActiveRecord::Base
  STATUSES = %w[active consent_required revoked].freeze

  belongs_to :user
  belongs_to :client, class_name: "McpOauthClient", foreign_key: :mcp_oauth_client_id
  has_many :scope_records,
           class_name: "McpOauthAuthorizationScope",
           dependent: :destroy,
           inverse_of: :authorization
  has_many :access_tokens, class_name: "McpOauthAccessToken", dependent: :destroy
  has_many :refresh_tokens, class_name: "McpOauthRefreshToken", dependent: :destroy

  validates :resource, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :active, -> { where(status: "active", revoked_at: nil) }

  def scopes
    scope_records.map(&:name)
  end

  def active?
    status == "active" && revoked_at.nil?
  end

  def consent_current?(consent_required_at: McpPrimitive.maximum(:consent_required_at))
    consent_required_at.blank? || consented_at >= consent_required_at
  end

  def self.require_consent!(scopes: nil, client_ids: nil)
    transaction do
      authorizations = active
      if scopes.present?
        authorization_ids =
          McpOauthAuthorizationScope.where(name: scopes).select(:mcp_oauth_authorization_id)
        authorizations = authorizations.where(id: authorization_ids)
      end
      authorizations = authorizations.where(mcp_oauth_client_id: client_ids) if client_ids.present?
      authorization_ids = authorizations.select(:id)
      now = Time.zone.now
      McpOauthAccessToken.where(
        mcp_oauth_authorization_id: authorization_ids,
        revoked_at: nil,
      ).update_all(revoked_at: now, updated_at: now)
      McpOauthRefreshToken.where(
        mcp_oauth_authorization_id: authorization_ids,
        revoked_at: nil,
      ).update_all(revoked_at: now, updated_at: now)
      authorizations.update_all(status: "consent_required", updated_at: now)
    end
  end

  def revoke!(by_user: nil, reason: nil)
    transaction do
      update!(
        status: "revoked",
        revoked_at: Time.zone.now,
        revoked_by_user_id: by_user&.id,
        revoked_reason: reason,
      )
      access_tokens.where(revoked_at: nil).update_all(revoked_at: Time.zone.now)
      refresh_tokens.where(revoked_at: nil).update_all(revoked_at: Time.zone.now)
    end
  end
end

# == Schema Information
#
# Table name: mcp_oauth_authorizations
#
#  id                   :bigint           not null, primary key
#  client_metadata_hash :string
#  consented_at         :datetime         not null
#  grant_version        :integer          default(1), not null
#  resource             :string           not null
#  revoked_at           :datetime
#  revoked_reason       :string
#  status               :string           default("active"), not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  mcp_oauth_client_id  :bigint           not null
#  revoked_by_user_id   :integer
#  user_id              :integer          not null
#
# Indexes
#
#  idx_mcp_active_authorizations_unique                   (user_id,mcp_oauth_client_id) UNIQUE WHERE (revoked_at IS NULL)
#  index_mcp_oauth_authorizations_on_mcp_oauth_client_id  (mcp_oauth_client_id)
#
