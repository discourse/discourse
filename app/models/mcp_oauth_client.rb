# frozen_string_literal: true

class McpOauthClient < ActiveRecord::Base
  REGISTRATION_TYPES = %w[pre_registered cimd].freeze
  TRUST_STATES = %w[pending approved blocked].freeze
  LOOPBACK_IP_HOSTS = %w[127.0.0.1 ::1].freeze
  LOCAL_REDIRECT_HOSTS = ["localhost", *LOOPBACK_IP_HOSTS].freeze

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

  def allows_redirect_uri?(value)
    return true if redirect_uris.include?(value)

    requested_uri = URI.parse(value)
    return false if !loopback_ip_redirect_uri?(requested_uri)

    redirect_uris.any? do |registered_value|
      registered_uri = URI.parse(registered_value)
      loopback_ip_redirect_uri?(registered_uri) &&
        redirect_uris_match_except_port?(registered_uri, requested_uri)
    end
  rescue URI::InvalidURIError
    false
  end

  def self.valid_redirect_uri?(value)
    uri = URI.parse(value)
    if !uri.absolute? || uri.host.blank? || uri.userinfo.present? || uri.fragment.present?
      return false
    end
    return true if uri.scheme == "https"

    uri.scheme == "http" && LOCAL_REDIRECT_HOSTS.include?(uri.hostname.downcase)
  rescue URI::InvalidURIError
    false
  end

  private

  def loopback_ip_redirect_uri?(uri)
    uri.scheme == "http" && LOOPBACK_IP_HOSTS.include?(uri.hostname&.downcase)
  end

  def redirect_uris_match_except_port?(registered_uri, requested_uri)
    %i[scheme userinfo hostname path query fragment].all? do |component|
      registered_uri.public_send(component) == requested_uri.public_send(component)
    end
  end

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
