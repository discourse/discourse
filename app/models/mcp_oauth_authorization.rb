# frozen_string_literal: true

class McpOauthAuthorization < ActiveRecord::Base
  STATUSES = %w[active consent_required revoked].freeze

  belongs_to :user
  belongs_to :client, class_name: "McpOauthClient", foreign_key: :mcp_oauth_client_id
  belongs_to :profile, class_name: "McpServerProfile", foreign_key: :mcp_server_profile_id
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
#  id                    :bigint           not null, primary key
#  client_metadata_hash  :string
#  consent_revision      :integer          default(1), not null
#  consented_at          :datetime         not null
#  grant_version         :integer          default(1), not null
#  resource              :string           not null
#  revoked_at            :datetime
#  revoked_reason        :string
#  status                :string           default("active"), not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  mcp_oauth_client_id   :bigint           not null
#  mcp_server_profile_id :bigint           not null
#  revoked_by_user_id    :integer
#  user_id               :integer          not null
#
# Indexes
#
#  idx_mcp_active_authorizations_unique                     (user_id,mcp_oauth_client_id,mcp_server_profile_id) UNIQUE WHERE (revoked_at IS NULL)
#  index_mcp_oauth_authorizations_on_mcp_oauth_client_id    (mcp_oauth_client_id)
#  index_mcp_oauth_authorizations_on_mcp_server_profile_id  (mcp_server_profile_id)
#
