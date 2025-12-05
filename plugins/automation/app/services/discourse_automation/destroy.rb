# frozen_string_literal: true

class DiscourseAutomation::Destroy
  include Service::Base

  # @!method self.call(guardian:, params:)
  #   @param [Guardian] guardian
  #   @param [Hash] params
  #   @option params [Integer] :automation_id
  #   @return [Service::Base::Context]

  policy :can_destroy_automation

  params do
    attribute :automation_id, :integer
    validates :automation_id, presence: true
  end

  model :automation

  transaction do
    step :log_action
    step :destroy_automation
  end

  private

  def can_destroy_automation(guardian:)
    guardian.is_admin?
  end

  def fetch_automation(params:)
    DiscourseAutomation::Automation.find_by(id: params.automation_id)
  end

  def log_action(automation:, guardian:)
    details = { id: automation.id }
    details[:name] = automation.name if automation.name.present?
    details[:script] = automation.script if automation.script.present?
    details[:trigger] = automation.trigger if automation.trigger.present?

    StaffActionLogger.new(guardian.user).log_custom("delete_automation", **details)
  end

  def destroy_automation(automation:)
    automation.destroy!
  end
end
