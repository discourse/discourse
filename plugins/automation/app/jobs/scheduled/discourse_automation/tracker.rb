# frozen_string_literal: true

module Jobs
  module DiscourseAutomation
    class Tracker < ::Jobs::Scheduled
      every 1.minute

      BATCH_LIMIT = 300

      def execute(_args = nil)
        return unless SiteSetting.discourse_automation_enabled

        ::DiscourseAutomation::PendingAutomation
          .includes(:automation)
          .limit(BATCH_LIMIT)
          .where("execute_at < ?", Time.now)
          .find_each do |pending_automation|
            run_pending_automation(pending_automation)
          rescue => e
            ::DiscourseAutomation::Logger.error(
              "Error running automation '#{pending_automation.automation.name}': #{e.message}",
            )
          end

        ::DiscourseAutomation::PendingPm
          .includes(:automation)
          .limit(BATCH_LIMIT)
          .where("execute_at < ?", Time.now)
          .find_each { |pending_pm| send_pending_pm(pending_pm) }
      end

      def send_pending_pm(pending_pm)
        DistributedMutex.synchronize(
          "automation_send_pending_pm_#{pending_pm.id}",
          validity: 30.minutes,
        ) do
          next if !::DiscourseAutomation::PendingPm.exists?(pending_pm.id)

          ::DiscourseAutomation::Scriptable::Utils.send_pm(
            pending_pm.attributes.slice("target_usernames", "title", "raw"),
            sender: pending_pm.sender,
            prefers_encrypt: pending_pm.prefers_encrypt,
          )

          pending_pm.destroy!
        end
      rescue ActiveRecord::RecordNotSaved => e
        ::DiscourseAutomation::Logger.error(
          "Failed to send pending PM '#{pending_pm.title}': #{e.message}",
        )
        pending_pm.destroy!
      rescue => e
        ::DiscourseAutomation::Logger.error(
          "Error sending pending PM '#{pending_pm.title}': #{e.message}",
        )
      end

      def run_pending_automation(pending_automation)
        DistributedMutex.synchronize(
          "process_pending_automation_#{pending_automation.id}",
          validity: 30.minutes,
        ) do
          next if !::DiscourseAutomation::PendingAutomation.exists?(pending_automation.id)

          pending_automation.automation.trigger!(
            "kind" => pending_automation.automation.trigger,
            "execute_at" => pending_automation.execute_at,
          )

          pending_automation.destroy!
        end
      end
    end
  end
end
