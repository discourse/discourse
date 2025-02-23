# frozen_string_literal: true

module Jobs
  # various consistency checks
  class EnsureDbConsistency < ::Jobs::Scheduled
    every 12.hours

    def execute(args)
      @measure_times = []

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
        ::UserAction,
        ::UserStat,
        ::GroupUser,
      ].each do |klass|
        measure_start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        begin
          if [::UserAction, ::UserStat, ::GroupUser].include?(klass)
            klass.ensure_consistency!(13.hours.ago)
          else
            klass.ensure_consistency!
          end
        rescue StandardError => e
          Rails.logger.error("Error ensuring consistency for #{klass}: #{e.message}")
        end

        @measure_times << [klass, Process.clock_gettime(Process::CLOCK_MONOTONIC) - measure_start]
      end

      Rails.logger.debug(format_measure)
      nil
    end

    private

    def format_measure
      result = +"EnsureDbConsistency Times\n"
      result << @measure_times.map { |name, duration| "  #{name}: #{duration}" }.join("\n")
      result
    end
  end
end
