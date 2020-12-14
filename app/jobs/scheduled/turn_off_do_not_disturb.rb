# frozen_string_literal: true

module Jobs
  class TurnOffDoNotDisturb < ::Jobs::Scheduled
    every 1.minute

    def execute(args = nil)
      now = Time.current
      DoNotDisturbTiming.includes(:user).where('ends_at <= ? AND ends_at > ?', now, now - 1.minute).each do |timing|
        timing.user.publish_do_not_disturb(ends_at: nil)
      end
    end
  end
end
