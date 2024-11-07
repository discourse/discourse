# frozen_string_literal: true

class Flags::CreateFlag
  include Service::Base

  policy :invalid_access
  params do
    attribute :name, :string
    attribute :description, :string
    attribute :require_message, :boolean
    attribute :enabled, :boolean
    attribute :applies_to
    attribute :auto_action_type, :boolean

    validates :name, presence: true
    validates :description, presence: true
    validates :name, length: { maximum: Flag::MAX_NAME_LENGTH }
    validates :description, length: { maximum: Flag::MAX_DESCRIPTION_LENGTH }
    validates :applies_to, inclusion: { in: -> { Flag.valid_applies_to_types } }, allow_nil: false
  end
  policy :unique_name
  transaction do
    model :flag, :create_flag
    step :log
  end

  private

  def invalid_access(guardian:)
    guardian.can_create_flag?
  end

  def unique_name(params:)
    !Flag.custom.where(name: params.name).exists?
  end

  def create_flag(params:)
    Flag.create(params.merge(notify_type: true))
  end

  def log(guardian:, flag:)
    StaffActionLogger.new(guardian.user).log_custom(
      "create_flag",
      {
        name: flag.name,
        description: flag.description,
        applies_to: flag.applies_to,
        require_message: flag.require_message,
        enabled: flag.enabled,
      },
    )
  end
end
