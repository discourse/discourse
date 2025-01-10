# frozen_string_literal: true

module Jobs
  # various consistency checks
  class EnsureDbConsistency < ::Jobs::Scheduled
    every 12.hours

    def execute(args)
      start_measure

      # we don't want to have a situation where Jobs::Badge or stuff like that is attempted to be run
      # so we always prefix with :: to ensure we are running models

      [
        ::UserVisit,
        ::Group,
        ::Notification,
        ::TopicFeaturedUsers,
        ::PostRevision,
        ::Topic,
        ::Badge,
        ::CategoryUser,
        ::UserOption,
        ::Tag,
        ::CategoryTagStat,
        ::User,
        ::UserAvatar,
        ::UserEmail,
        ::Category,
        ::TopicThumbnail,
      ].each do |klass|
        klass.ensure_consistency!
        measure(klass)
      end

      UserAction.ensure_consistency!(13.hours.ago)
      measure(UserAction)

      UserStat.ensure_consistency!(13.hours.ago)
      measure(UserStat)

      GroupUser.ensure_consistency!(13.hours.ago)
      measure(GroupUser)

      Rails.logger.debug(format_measure)
      nil
    end

    private

    def format_measure
      result = +"EnsureDbConsistency Times\n"
      result << @measure_times.map { |name, duration| "  #{name}: #{duration}" }.join("\n")
      result
    end

    def start_measure
      @measure_times = []
      @measure_start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def measure(step = nil)
      @measure_now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      @measure_times << [step, @measure_now - @measure_start] if @measure_start
      @measure_start = @measure_now
    end
  end
end
