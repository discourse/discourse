# frozen_string_literal: true

module Jobs
  class DiscourseAutomation::Trigger < ::Jobs::Base
    RETRY_TIMES = [5.minute, 15.minute, 120.minute].freeze

    sidekiq_options retry: RETRY_TIMES.size

    sidekiq_retry_in do |count, exception|
      # returning nil/0 will trigger the default sidekiq
      # retry formula
      #
      # See https://github.com/mperham/sidekiq/blob/3330df0ee37cfd3e0cd3ef01e3e66b584b99d488/lib/sidekiq/job_retry.rb#L216-L234
      case exception.wrapped
      when SocketError
        return RETRY_TIMES[count]
      end
    end

    def execute(args)
      automation =
        ::DiscourseAutomation::Automation.find_by(id: args[:automation_id], enabled: true)

      return if !automation

      context = ::DiscourseAutomation::Automation.deserialize_context(args[:context])

      automation.running_in_background!
      automation.trigger!(context)
    end
  end
end
