# frozen_string_literal: true

class DiscourseAutomation::Create
  include Service::Base

  # @!method self.call(guardian:, params:)
  #   @param [Guardian] guardian
  #   @param [Hash] params
  #   @option params [String] :script
  #   @option params [String] :trigger
  #   @return [Service::Base::Context]

  policy :can_create_automation

  params do
    attribute :script, :string
    attribute :trigger, :string

    validates :script, presence: true
  end

  model :automation, :instantiate_automation

  transaction do
    step :apply_forced_triggerable
    step :save_automation
    step :log_action
  end

  private

  def can_create_automation(guardian:)
    guardian.is_admin?
  end

  def instantiate_automation(params:, guardian:)
    DiscourseAutomation::Automation.new(
      script: params.script,
      trigger: params.trigger,
      last_updated_by_id: guardian.user.id,
    )
  end

  def apply_forced_triggerable(automation:)
    if automation.scriptable&.forced_triggerable
      automation.trigger = automation.scriptable.forced_triggerable[:triggerable].to_s
    end
  end

  def save_automation(automation:)
    automation.save!
  end

  def log_action(automation:, guardian:)
    StaffActionLogger.new(guardian.user).log_custom(
      "create_automation",
      automation.slice(:id, :name, :script, :trigger).compact_blank,
    )
  end
end
