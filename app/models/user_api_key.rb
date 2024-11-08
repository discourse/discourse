# frozen_string_literal: true

class UserApiKey < ActiveRecord::Base
  self.ignored_columns = [
    "scopes", # TODO: Remove when 20240212034010_drop_deprecated_columns has been promoted to pre-deploy
    "client_id", # TODO: Add post-migration to remove column after 3.4.0 stable release (not before early 2025)
    "application_name", # TODO: Add post-migration to remove column after 3.4.0 stable release (not before early 2025)
  ]

  REVOKE_MATCHER = RouteMatcher.new(actions: "user_api_keys#revoke", methods: :post, params: [:id])

  belongs_to :user
  belongs_to :client, class_name: "UserApiKeyClient", foreign_key: "user_api_key_client_id"
  has_many :scopes, class_name: "UserApiKeyScope", dependent: :destroy

  scope :active, -> { where(revoked_at: nil) }
  scope :with_key, ->(key) { where(key_hash: ApiKey.hash_key(key)) }

  after_initialize :generate_key

  def generate_key
    if !self.key_hash
      @key ||= SecureRandom.hex
      self.key_hash = ApiKey.hash_key(@key)
    end
  end

  def key
    unless key_available?
      raise ApiKey::KeyAccessError.new "API key is only accessible immediately after creation"
    end
    @key
  end

  def key_available?
    @key.present?
  end

  def ensure_allowed!(env)
    raise Discourse::InvalidAccess.new if !allow?(env)
  end

  def update_last_used(client_id)
    update_args = { last_used_at: Time.zone.now }
    if client_id.present? && client_id != self.client.client_id
      new_client =
        UserApiKeyClient.create!(
          client_id: client_id,
          application_name: self.client.application_name,
        )
      update_args[:user_api_key_client_id] = new_client.id
    end
    self.update_columns(**update_args)
  end

  # Scopes allowed to be requested by external services
  def self.allowed_scopes
    Set.new(SiteSetting.allow_user_api_key_scopes.split("|"))
  end

  def self.available_scopes
    @available_scopes ||= Set.new(UserApiKeyScopes.all_scopes.keys.map(&:to_s))
  end

  def has_push?
    scopes.any? { |s| s.name == "push" || s.name == "notifications" } && push_url.present? &&
      SiteSetting.allowed_user_api_push_urls.include?(push_url)
  end

  def allow?(env)
    scopes.any? { |s| s.permits?(env) } || is_revoke_self_request?(env)
  end

  private

  def revoke_self_matcher
    REVOKE_MATCHER.with_allowed_param_values({ "id" => [nil, id.to_s] })
  end

  def is_revoke_self_request?(env)
    revoke_self_matcher.match?(env: env)
  end
end

# == Schema Information
#
# Table name: user_api_keys
#
#  id                     :integer          not null, primary key
#  user_id                :integer          not null
#  push_url               :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  revoked_at             :datetime
#  last_used_at           :datetime         not null
#  key_hash               :string           not null
#  user_api_key_client_id :bigint
#
# Indexes
#
#  index_user_api_keys_on_client_id               (client_id) UNIQUE
#  index_user_api_keys_on_key_hash                (key_hash) UNIQUE
#  index_user_api_keys_on_user_api_key_client_id  (user_api_key_client_id)
#  index_user_api_keys_on_user_id                 (user_id)
#
