# frozen_string_literal: true

class User::CreateBot
  include Service::Base

  policy :can_create_bot
  policy :site_not_archived

  params do
    attribute :name, :string
    attribute :username, :string
    attribute :trust_level, :integer, default: -> { SiteSetting.default_trust_level }

    validates :name,
              presence: true,
              if: -> { SiteSetting.full_name_requirement == "required_at_signup" }
    validates :username, presence: true
    validates :trust_level, inclusion: { in: TrustLevel.valid_range }
    validate :trust_level_is_integer
    validate :text_attributes_are_strings

    def text_attributes_are_strings
      %w[name username].each do |attribute|
        value = raw_attributes[attribute]
        errors.add(attribute, :invalid) unless value.nil? || value.is_a?(String)
      end
    end

    def trust_level_is_integer
      value = raw_attributes["trust_level"]
      return if value.is_a?(Integer)
      return if value.is_a?(String) && value.match?(/\A[0-4]\z/)

      errors.add(:trust_level, :not_an_integer)
    end
  end

  transaction do
    model :user, :create_bot
    step :log_creation
  end

  private

  def can_create_bot(guardian:)
    guardian.is_admin?
  end

  def site_not_archived
    !SiteSetting.site_archived
  end

  def create_bot(params:, guardian:)
    User.create(
      id: BotUser.next_id,
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
end
