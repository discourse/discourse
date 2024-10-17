# frozen_string_literal: true

class Flags::ReorderFlag
  include Service::Base

  contract do
    attribute :flag_id, :integer
    attribute :direction, :string

    validates :flag_id, presence: true
    validates :direction, inclusion: { in: %w[up down] }
  end
  model :flag
  policy :invalid_access
  model :all_flags
  policy :invalid_move
  transaction do
    step :move
    step :log
  end

  private

  def fetch_flag(contract:)
    Flag.find_by(id: contract.flag_id)
  end

  def invalid_access(guardian:, flag:)
    guardian.can_reorder_flag?(flag)
  end

  def fetch_all_flags
    Flag.where.not(name_key: "notify_user").order(:position)
  end

  def invalid_move(flag:, contract:, all_flags:)
    return false if all_flags.first == flag && contract.direction == "up"
    return false if all_flags.last == flag && contract.direction == "down"
    true
  end

  def move(flag:, contract:, all_flags:)
    old_position = flag.position
    index = all_flags.index(flag)
    target_flag = all_flags[contract.direction == "up" ? index - 1 : index + 1]

    flag.update!(position: target_flag.position)
    target_flag.update!(position: old_position)
  end

  def log(guardian:, flag:, contract:)
    StaffActionLogger.new(guardian.user).log_custom(
      "move_flag",
      { flag: flag.name, direction: contract.direction },
    )
  end
end
