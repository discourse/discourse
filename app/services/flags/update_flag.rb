# frozen_string_literal: true

class Flags::UpdateFlag
  include Service::Base

  params do
    attribute :id, :integer
    attribute :name, :string
    attribute :description, :string
    attribute :require_message, :boolean
    attribute :enabled, :boolean
    attribute :applies_to
    attribute :auto_action_type, :boolean

    validates :id, presence: true
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

  def fetch_flag(params:)
    Flag.find_by(id: params[:id])
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

  def unique_name(params:)
    !Flag.custom.where(name: params[:name]).where.not(id: params[:id]).exists?
  end

  def update(flag:, params:)
    flag.update!(**params)
  end

  def log(guardian:, flag:)
    StaffActionLogger.new(guardian.user).log_custom(
      "update_flag",
      flag.slice(:name, :description, :applies_to, :require_message, :enabled),
    )
  end
end
