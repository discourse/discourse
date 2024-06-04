# frozen_string_literal: true

class ToggleFlag
  include Service::Base

  contract
  model :flag
  policy :invalid_access

  transaction do
    step :toggle
    step :log
  end

  class Contract
    attribute :flag_id, :integer
    validates :flag_id, presence: true
  end

  private

  def fetch_flag(flag_id:)
    Flag.find(flag_id)
  end

  def invalid_access(guardian:)
    guardian.can_toggle_flag?
  end

  def toggle(flag:)
    flag.update!(enabled: !flag.enabled)
  end

  def log(guardian:, flag:)
    StaffActionLogger.new(guardian.user).log_custom(
      "toggle_flag",
      { flag: flag.name, enabled: flag.enabled },
    )
  end
end
