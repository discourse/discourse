# frozen_string_literal: true

module Jobs
  class UpdateHeatSettings < ::Jobs::Scheduled
    every 1.month

    def execute(args)
      HeatSettingsUpdater.update
    end
  end
end
