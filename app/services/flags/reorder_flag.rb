# frozen_string_literal: true

class Flags::ReorderFlag
  include Service::Base

  params do
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

  def fetch_flag(params:)
    Flag.find_by(id: params.flag_id)
  end

  def invalid_access(guardian:, flag:)
    guardian.can_reorder_flag?(flag)
  end

  def fetch_all_flags
    Flag.where.not(name_key: "notify_user").order(:position).to_a
  end

  def invalid_move(flag:, params:, all_flags:)
    return false if all_flags.first == flag && params.direction == "up"
    return false if all_flags.last == flag && params.direction == "down"
    true
  end

  def move(flag:, params:, all_flags:)
    old_position = flag.position
    index = all_flags.index(flag)
    target_flag = all_flags[params.direction == "up" ? index - 1 : index + 1]

    flag.update!(position: target_flag.position)
    target_flag.update!(position: old_position)
  end

  def log(guardian:, flag:, params:)
    StaffActionLogger.new(guardian.user).log_custom(
      "move_flag",
      { flag: flag.name, direction: params.direction },
    )
  end
end
