# frozen_string_literal: true

class McpServerProfile < ActiveRecord::Base
  DEFAULT_SLUG = "default"
  DEFAULT_SCOPES = %w[mcp:profile:discover mcp:content:read].freeze

  has_many :capability_policies,
           class_name: "McpServerProfileCapability",
           dependent: :destroy,
           inverse_of: :profile
  has_many :oauth_authorizations, class_name: "McpOauthAuthorization", dependent: :destroy

  validates :name, presence: true, length: { maximum: 100 }
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9_-]+\z/ }
  validates :cache_ttl_ms, numericality: { only_integer: true, in: 1_000..86_400_000 }

  before_validation :include_admin_group

  def self.default
    find_by(slug: DEFAULT_SLUG)
  end

  def self.ensure_default!
    profile =
      find_or_create_by!(slug: DEFAULT_SLUG) do |new_profile|
        new_profile.name = "Discourse"
        new_profile.enabled = false
        new_profile.allowed_group_ids = SiteSetting.mcp_server_allowed_groups_map
        new_profile.allowed_scopes = DEFAULT_SCOPES
      end
    if !profile.allowed_group_ids.include?(Group::AUTO_GROUPS[:admins])
      profile.update!(allowed_group_ids: profile.allowed_group_ids | [Group::AUTO_GROUPS[:admins]])
    end
    profile
  end

  def available?
    SiteSetting.mcp_server_enabled && enabled?
  end

  def user_allowed?(user)
    return false if user.blank? || !user.active? || user.suspended? || user.staged?
    return true if user.admin?

    (allowed_group_ids & user.group_ids).present?
  end

  def bump_catalog_revision!(consent_relevant: false)
    increment!(:catalog_revision)
    increment!(:consent_revision) if consent_relevant
  end

  private

  def include_admin_group
    self.allowed_group_ids = Array(allowed_group_ids) | [Group::AUTO_GROUPS[:admins]]
  end
end

# == Schema Information
#
# Table name: mcp_server_profiles
#
#  id                :bigint           not null, primary key
#  allowed_group_ids :integer          default([]), not null, is an Array
#  allowed_scopes    :string           default([]), not null, is an Array
#  cache_ttl_ms      :integer          default(300000), not null
#  catalog_revision  :integer          default(1), not null
#  consent_revision  :integer          default(1), not null
#  enabled           :boolean          default(FALSE), not null
#  instructions      :text
#  name              :string           not null
#  slug              :string           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
# Indexes
#
#  index_mcp_server_profiles_on_slug  (slug) UNIQUE
#
