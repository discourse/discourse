# frozen_string_literal: true

VALID_DIRECTIONS = %w[up down]

class Flags::ReorderFlag
  include Service::Base

  contract
  model :flag
  policy :invalid_access
  policy :invalid_move

  transaction do
    step :move
    step :log
  end

  class Contract
    attribute :flag_id, :integer
    attribute :direction, :string
    validates :flag_id, presence: true
    validates :direction, inclusion: { in: VALID_DIRECTIONS }
  end

  private

  def fetch_flag(flag_id:)
    Flag.find(flag_id)
  end

  def invalid_access(guardian:, flag:)
    guardian.can_reorder_flag?(flag)
  end

  def all_flags
    @all_flags ||= Flag.where.not(name_key: "notify_user").order(:position)
  end

  def invalid_move(flag:, direction:)
    return false if all_flags.first == flag && direction == "up"
    return false if all_flags.last == flag && direction == "down"
    true
  end

  def move(flag:, direction:)
    old_position = flag.position
    index = all_flags.index(flag)
    target_flag = all_flags[direction == "up" ? index - 1 : index + 1]

    flag.update!(position: target_flag.position)
    target_flag.update!(position: old_position)
  end

  def log(guardian:, flag:, direction:)
    StaffActionLogger.new(guardian.user).log_custom(
      "move_flag",
      { flag: flag.name, direction: direction },
    )
  end
end
