# frozen_string_literal: true

module Jobs
  class CleanUpStylesheetCache < ::Jobs::Scheduled
    every 1.week

    def execute(args)
      StylesheetCache.clean_up
    end
  end
end
