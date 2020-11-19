# frozen_string_literal: true

module Jobs
  class DiscourseAutomationTracker < ::Jobs::Scheduled
    every 1.minute

    def execute(_args = nil)
      return unless SiteSetting.discourse_automation_enabled

      DiscourseAutomation::PendingAutomation
        .includes(automation: [:trigger])
        .limit(300)
        .where('execute_at < ?', Time.now)
        .find_each do |pending_automation|
          run_pending_automation(pending_automation)
        end
    end

    def run_pending_automation(pending_automation)
      DiscourseAutomation::Script.all.each do |name|
        type = name.to_s.gsub('script_', '')

        next if type != pending_automation.automation.script

        script = DiscourseAutomation::Script.new(pending_automation.automation)
        script.public_send(name)
        script.script_block.call

        pending_automation.destroy!
      end
    end
  end
end
