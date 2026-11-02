# frozen_string_literal: true

class User::CreateBot
  include Service::Base

  policy :can_create_bot
  policy :site_not_archived

  params do
    attribute :name, :string
    attribute :username, :string
    attribute :trust_level, :integer, default: -> { SiteSetting.default_trust_level }
    attribute :api_key, :hash do
      attribute :description, :string
      attribute :scope_mode, :string
      attribute :scopes, :array

      validates :description, length: { maximum: 255 }
      validates :scope_mode, inclusion: { in: ApiKey.scope_modes.keys }
    end

    validates :name,
              presence: true,
              if: -> { SiteSetting.full_name_requirement == "required_at_signup" }
    validates :username, presence: true
    validates :trust_level, inclusion: { in: TrustLevel.valid_range }
  end

  # Commit the reservation before the creation transaction can hide it from other requests.
  model :bot_id, :reserve_bot_id

  transaction do
    model :user, :create_bot
    step :log_creation
    only_if(:api_key_requested) do
      model :api_key, :create_api_key
      step :log_api_key_creation
    end
  end

  private

  def can_create_bot(guardian:)
    guardian.is_admin?
  end

  def site_not_archived
    !SiteSetting.site_archived
  end

  def reserve_bot_id
    BotUser.new("core").next_id
  end

  def create_bot(params:, guardian:, bot_id:)
    User.create(
      id: bot_id,
      name: params.name,
      username: params.username,
      trust_level: params.trust_level,
      email: "#{SecureRandom.hex}@does-not-exist.invalid",
      active: true,
      approved: true,
      approved_by_id: guardian.user.id,
      approved_at: Time.current,
      admin: false,
      moderator: false,
      enforce_username_restrictions: true,
      # Internal addresses are not subject to signup email-domain restrictions.
      skip_email_validation: true,
    )
  end

  def log_creation(user:, guardian:)
    StaffActionLogger.new(guardian.user).log_bot_creation(user)
  end

  def api_key_requested(params:)
    params.api_key.present?
  end

  def create_api_key(params:, user:, guardian:)
    ApiKey.create(
      user:,
      created_by: guardian.user,
      description: params.api_key.description.presence || user.username,
      scope_mode: params.api_key.scope_mode,
      api_key_scopes: ApiKeyScope.build_from_params(params.api_key.scopes),
    )
  end

  def log_api_key_creation(api_key:, guardian:)
    StaffActionLogger.new(guardian.user).log_api_key(
      api_key,
      UserHistory.actions[:api_key_create],
      changes: api_key.saved_changes,
    )
  end
end
