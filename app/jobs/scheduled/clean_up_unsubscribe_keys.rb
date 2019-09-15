# frozen_string_literal: true

module Jobs

  class CleanUpUnsubscribeKeys < ::Jobs::Scheduled
    every 1.day

    def execute(args)
      UnsubscribeKey.where('created_at < ?', 2.months.ago).delete_all
    end

  end

end
