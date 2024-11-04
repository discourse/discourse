# frozen_string_literal: true

module DiscourseAutomation
  class DestroyAutomation
    include ::Service::Base

    # @!method self.call(guardian:, params:)
    #   @param [Guardian] guardian
    #   @param [Hash] params
    #   @option params [Integer] :automation_id
    #   @return [Service::Base::Context]
    params do
      attribute :automation_id, :integer
      validates :automation_id, presence: true
    end

    model :automation
    policy :can_destroy_automation
    transaction do
      step :log_action
      step :destroy_automation
    end

    private

    def fetch_automation(params:)
      DiscourseAutomation::Automation.find_by(id: params.automation_id)
    end

    def can_destroy_automation(guardian:)
      guardian.user.admin?
    end

    def log_action(automation:, guardian:)
      StaffActionLogger.new(guardian.user).log_custom(
        "delete_automation",
        id: automation.id,
        name: automation.name,
        script: automation.script,
        trigger: automation.trigger,
      )
    end

    def destroy_automation(automation:)
      automation.destroy!
    end
  end
end
