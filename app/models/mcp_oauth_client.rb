# frozen_string_literal: true

class McpOauthClient < ActiveRecord::Base
  REGISTRATION_TYPES = %w[pre_registered cimd].freeze
  TRUST_STATES = %w[pending approved blocked].freeze

  has_many :authorizations, class_name: "McpOauthAuthorization", dependent: :destroy

  validates :client_id, presence: true, uniqueness: true, length: { maximum: 1000 }
  validates :name, presence: true, length: { maximum: 255 }
  validates :registration_type, inclusion: { in: REGISTRATION_TYPES }
  validates :trust_state, inclusion: { in: TRUST_STATES }
  validates :redirect_uris, presence: true
  validate :redirect_uris_are_absolute

  def approved?
    trust_state == "approved"
  end

  def blocked?
    trust_state == "blocked"
  end

  def self.valid_redirect_uri?(value)
    uri = URI.parse(value)
    if !uri.absolute? || uri.host.blank? || uri.userinfo.present? || uri.fragment.present?
      return false
    end
    return true if uri.scheme == "https"

    uri.scheme == "http" && %w[localhost 127.0.0.1 ::1].include?(uri.host.downcase)
  rescue URI::InvalidURIError
    false
  end

  private

  def redirect_uris_are_absolute
    return if redirect_uris.blank?

    if !redirect_uris.all? { |value| self.class.valid_redirect_uri?(value) }
      errors.add(:redirect_uris, :invalid)
    end
  end
end

# == Schema Information
#
# Table name: mcp_oauth_clients
#
#  id                  :bigint           not null, primary key
#  last_seen_at        :datetime
#  metadata            :jsonb            not null
#  metadata_expires_at :datetime
#  metadata_hash       :string
#  metadata_uri        :string
#  name                :string           not null
#  redirect_uris       :string           default([]), not null, is an Array
#  registration_type   :string           not null
#  trust_state         :string           default("approved"), not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  client_id           :string           not null
#
# Indexes
#
#  index_mcp_oauth_clients_on_client_id  (client_id) UNIQUE
#
