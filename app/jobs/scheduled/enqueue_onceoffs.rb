# frozen_string_literal: true

module Jobs

  class EnqueueOnceoffs < ::Jobs::Scheduled
    every 10.minutes

    def execute(args)
      ::Jobs::Onceoff.enqueue_all
    end
  end

end
