# frozen_string_literal: true

class Flags::DestroyFlag
  include Service::Base

  params do
    attribute :id, :integer

    validates :id, presence: true
  end

  model :flag
  policy :not_system
  policy :not_used
  policy :invalid_access

  transaction do
    step :destroy
    step :log
  end

  private

  def fetch_flag(params:)
    Flag.find_by(id: params.id)
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

  def destroy(flag:)
    flag.destroy!
  end

  def log(guardian:, flag:)
    StaffActionLogger.new(guardian.user).log_custom(
      "delete_flag",
      flag.slice(:name, :description, :applies_to, :enabled),
    )
  end
end
