# frozen_string_literal: true

module Jobs
  class DiscourseAutomationTracker < ::Jobs::Scheduled
    every 1.minute

    BATCH_LIMIT = 300

    def execute(_args = nil)
      return unless SiteSetting.discourse_automation_enabled

      DiscourseAutomation::PendingAutomation
        .includes(:automation)
        .limit(BATCH_LIMIT)
        .where("execute_at < ?", Time.now)
        .find_each { |pending_automation| run_pending_automation(pending_automation) }

      DiscourseAutomation::PendingPm
        .includes(:automation)
        .limit(BATCH_LIMIT)
        .where("execute_at < ?", Time.now)
        .find_each { |pending_pm| send_pending_pm(pending_pm) }
    end

    def send_pending_pm(pending_pm)
      DiscourseAutomation::Scriptable::Utils.send_pm(
        pending_pm.attributes.slice("target_usernames", "title", "raw"),
        sender: pending_pm.sender,
        prefers_encrypt: pending_pm.prefers_encrypt,
      )

      pending_pm.destroy!
    end

    def run_pending_automation(pending_automation)
      pending_automation.automation.trigger!(
        "kind" => pending_automation.automation.trigger,
        "execute_at" => pending_automation.execute_at,
      )

      pending_automation.destroy!
    end
  end
end
