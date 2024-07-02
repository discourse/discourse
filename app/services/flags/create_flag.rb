# frozen_string_literal: true

class Flags::CreateFlag
  include Service::Base

  contract
  policy :invalid_access
  model :flag, :instantiate_flag

  transaction do
    step :create
    step :log
  end

  class Contract
    attribute :name, :string
    attribute :description, :string
    attribute :enabled, :boolean
    attribute :applies_to
    validates :name, presence: true
    validates :description, presence: true
    validates :name, length: { maximum: Flag::MAX_NAME_LENGTH }
    validates :description, length: { maximum: Flag::MAX_DESCRIPTION_LENGTH }
    validates :applies_to, inclusion: { in: Flag.valid_applies_to_types }, allow_nil: false
  end

  private

  def instantiate_flag(name:, description:, applies_to:, enabled:)
    Flag.new(
      name: name,
      description: description,
      applies_to: applies_to,
      enabled: enabled,
      notify_type: true,
    )
  end

  def invalid_access(guardian:)
    guardian.can_create_flag?
  end

  def create(flag:)
    flag.save!
  end

  def log(guardian:, flag:)
    StaffActionLogger.new(guardian.user).log_custom(
      "create_flag",
      {
        name: flag.name,
        description: flag.description,
        applies_to: flag.applies_to,
        enabled: flag.enabled,
      },
    )
  end
end
