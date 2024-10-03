# frozen_string_literal: true

class Flags::UpdateFlag
  include Service::Base

  contract do
    attribute :name, :string
    attribute :description, :string
    attribute :require_message, :boolean
    attribute :enabled, :boolean
    attribute :applies_to

    validates :name, presence: true
    validates :description, presence: true
    validates :name, length: { maximum: Flag::MAX_NAME_LENGTH }
    validates :description, length: { maximum: Flag::MAX_DESCRIPTION_LENGTH }
    validates :applies_to, inclusion: { in: -> { Flag.valid_applies_to_types } }, allow_nil: false
  end
  model :flag
  policy :not_system
  policy :not_used
  policy :invalid_access
  policy :unique_name
  transaction do
    step :update
    step :log
  end

  private

  def unique_name(id:, name:)
    !Flag.custom.where(name: name).where.not(id: id).exists?
  end

  def fetch_flag(id:)
    Flag.find(id)
  end

  def not_system(flag:)
    !flag.system?
  end

  def not_used(flag:)
    !flag.used?
  end

  def invalid_access(guardian:, flag:)
    guardian.can_edit_flag?(flag)
  end

  def update(flag:, name:, description:, applies_to:, require_message:, enabled:)
    flag.update!(
      name: name,
      description: description,
      applies_to: applies_to,
      require_message: require_message,
      enabled: enabled,
    )
  end

  def log(guardian:, flag:)
    StaffActionLogger.new(guardian.user).log_custom(
      "update_flag",
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
