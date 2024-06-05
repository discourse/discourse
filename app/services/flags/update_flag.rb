# frozen_string_literal: true

class Flags::UpdateFlag
  include Service::Base

  contract
  model :flag
  policy :invalid_access

  transaction do
    step :update
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

  def fetch_flag(id:)
    Flag.find(id)
  end

  def invalid_access(guardian:, flag:)
    guardian.can_edit_flag?(flag)
  end

  def update(flag:, name:, description:, applies_to:, enabled:)
    flag.update!(name: name, description: description, applies_to: applies_to, enabled: enabled)
  end

  def log(guardian:, flag:)
    StaffActionLogger.new(guardian.user).log_custom(
      "update_flag",
      {
        name: flag.name,
        description: flag.description,
        applies_to: flag.applies_to,
        enabled: flag.enabled,
      },
    )
  end
end
