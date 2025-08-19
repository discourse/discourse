# frozen_string_literal: true

class ApiKey < ActiveRecord::Base
  class KeyAccessError < StandardError
  end

  has_many :api_key_scopes
  belongs_to :user
  belongs_to :created_by, class_name: "User"

  scope :active, -> { where("revoked_at IS NULL") }
  scope :revoked, -> { where("revoked_at IS NOT NULL") }

  scope :with_key,
        ->(key) do
          hashed = self.hash_key(key)
          where(key_hash: hashed)
        end

  validates :description, length: { maximum: 255 }
  validate :at_least_one_granular_scope

  enum :scope_mode, %i[global read_only granular].freeze

  after_initialize :generate_key

  def generate_key
    if !self.key_hash
      @key ||= SecureRandom.hex(32) # Not saved to DB
      self.truncated_key = key[0..3]
      self.key_hash = ApiKey.hash_key(key)
    end
  end

  def key
    unless key_available?
      raise KeyAccessError.new "API key is only accessible immediately after creation"
    end
    @key
  end

  def key_available?
    @key.present?
  end

  def self.last_used_epoch
    SiteSetting.api_key_last_used_epoch.presence
  end

  def self.revoke_unused_keys!
    return if SiteSetting.revoke_api_keys_unused_days == 0 # Never expire keys
    to_revoke =
      active.where(
        "GREATEST(last_used_at, created_at, updated_at, :epoch) < :threshold",
        epoch: last_used_epoch,
        threshold: SiteSetting.revoke_api_keys_unused_days.days.ago,
      )

    to_revoke.find_each do |api_key|
      ApiKey.transaction do
        api_key.update!(revoked_at: Time.zone.now)

        StaffActionLogger.new(Discourse.system_user).log_api_key(
          api_key,
          UserHistory.actions[:api_key_update],
          changes: api_key.saved_changes,
          context:
            I18n.t(
              "staff_action_logs.api_key.automatic_revoked",
              count: SiteSetting.revoke_api_keys_unused_days,
            ),
        )
      end
    end
  end

  def self.revoke_max_life_keys!
    return if SiteSetting.revoke_api_keys_maxlife_days == 0

    revoke_days_ago = SiteSetting.revoke_api_keys_maxlife_days.days.ago
    to_revoke = ApiKey.active.where("created_at < ?", revoke_days_ago)

    to_revoke.find_each do |api_key|
      ApiKey.transaction do
        api_key.update!(revoked_at: Time.zone.now)

        StaffActionLogger.new(Discourse.system_user).log_api_key(
          api_key,
          UserHistory.actions[:api_key_update],
          changes: api_key.saved_changes,
          context:
            I18n.t(
              "staff_action_logs.api_key.automatic_revoked_max_life",
              count: SiteSetting.revoke_api_keys_maxlife_days,
            ),
        )
      end
    end
  end

  def self.hash_key(key)
    Digest::SHA256.hexdigest key
  end

  def request_allowed?(env)
    if allowed_ips.present? && allowed_ips.none? { |ip| ip.include?(Rack::Request.new(env).ip) }
      return false
    end
    return true if RouteMatcher.new(methods: :get, actions: "session#scopes").match?(env: env)

    api_key_scopes.blank? || api_key_scopes.any? { |s| s.permits?(env) }
  end

  def update_last_used!(now = Time.zone.now)
    return if last_used_at && (last_used_at > 1.minute.ago)

    # using update_column to avoid the AR transaction
    update_column(:last_used_at, now)
  end

  private

  def at_least_one_granular_scope
    if scope_mode == "granular" && api_key_scopes.empty?
      errors.add(
        :api_key_scopes,
        I18n.t("activerecord.errors.models.api_key.base.at_least_one_granular_scope"),
      )
    end
  end
end

# == Schema Information
#
# Table name: api_keys
#
#  id            :integer          not null, primary key
#  user_id       :integer
#  created_by_id :integer
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  allowed_ips   :inet             is an Array
#  hidden        :boolean          default(FALSE), not null
#  last_used_at  :datetime
#  revoked_at    :datetime
#  description   :text
#  key_hash      :string           not null
#  truncated_key :string           not null
#  scope_mode    :integer
#
# Indexes
#
#  index_api_keys_on_key_hash  (key_hash)
#  index_api_keys_on_user_id   (user_id)
#
