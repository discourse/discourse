# frozen_string_literal: true

module Migrations
  module DateHelper
    def self.human_readable_time(seconds)
      hours, remainder = seconds.divmod(3600)
      minutes, seconds = remainder.divmod(60)
      format("%02d:%02d:%02d", hours, minutes, seconds)
    end

    def self.track_time
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      yield
      Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
    end
  end
end
