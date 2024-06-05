# frozen_string_literal: true

class Flags::CreateFlag
  include Service::Base

  contract
  policy :invalid_access
  model :flag_instance, :instantiate_flag

  transaction do
    step :create
    step :log
  end

  class Contract
    attribute :name, :string
    attribute :description, :string
    attribute :enabled, :boolean
    attribute :applies_to
    validates :applies_to, inclusion: { in: Flag::VALID_APPLIES_TO }, allow_nil: false
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

  def create(flag_instance:)
    flag_instance.save!
  end

  def log(guardian:, flag_instance:)
    StaffActionLogger.new(guardian.user).log_custom(
      "create_flag",
      {
        name: flag_instance.name,
        description: flag_instance.description,
        applies_to: flag_instance.applies_to,
        enabled: flag_instance.enabled,
      },
    )
  end
end
