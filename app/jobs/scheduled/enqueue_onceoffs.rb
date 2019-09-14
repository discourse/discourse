# frozen_string_literal: true

module Jobs

  class EnqueueOnceoffs < Jobs::Scheduled
    every 10.minutes

    def execute(args)
      OnceoffBase.enqueue_all
    end
  end

end
