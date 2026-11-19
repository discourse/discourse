# frozen_string_literal: true

class Flags::MoveFlag
  include Service::Base

  params do
    attribute :flag_id, :integer
    attribute :position, :integer

    validates :flag_id, presence: true
    validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  end

  model :flag
  policy :invalid_access
  model :reorderable_flags
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

  def fetch_reorderable_flags
    Flag.where.not(name_key: "notify_user").order(:position).to_a
  end

  def invalid_move(params:, reorderable_flags:)
    params.position < reorderable_flags.size
  end

  def move(flag:, params:, reorderable_flags:)
    positions = reorderable_flags.map(&:position)
    reordered_flags = (reorderable_flags - [flag]).insert(params.position, flag)

    reordered_flags
      .zip(positions)
      .each { |reordered_flag, position| reordered_flag.update!(position:) }
  end

  def log(guardian:, flag:, params:)
    StaffActionLogger.new(guardian.user).log_custom(
      "move_flag",
      { flag: flag.name, position: params.position },
    )
  end
end
