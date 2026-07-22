# frozen_string_literal: true

module RackMiniProfilerAsyncSql
  def self.install
    return if !defined?(Rack::MiniProfiler)
    return if installed?

    suppress_adapter_recording_during_async_queries

    subscriber =
      ActiveSupport::Notifications.subscribe(
        "sql.active_record",
      ) do |_name, start, finish, _id, payload|
        next if !payload[:async]
        next if !Rack::MiniProfiler.current&.measure
        next if Rack::MiniProfiler.config.skip_schema_queries && payload[:name] =~ /SCHEMA/

        Rack::MiniProfiler.record_sql(
          payload[:sql],
          ((finish - start).to_f * 1000).round(1),
          Rack::MiniProfiler.binds_to_params(payload[:binds]),
        )
      end

    subscribers_by_notifier[ActiveSupport::Notifications.notifier] = subscriber
  end

  def self.installed?
    subscriber = subscribers_by_notifier[ActiveSupport::Notifications.notifier]
    subscriber &&
      ActiveSupport::Notifications.notifier.listeners_for("sql.active_record").include?(subscriber)
  end

  def self.subscribers_by_notifier
    @subscribers_by_notifier ||= {}
  end

  def self.suppress_adapter_recording_during_async_queries
    return if @suppression_installed

    SqlPatches.singleton_class.prepend(SqlPatchesAsyncSuppression)
    @suppression_installed = true
  end

  module SqlPatchesAsyncSuppression
    def should_measure?
      super && !async_active_record_query?
    end

    private

    def async_active_record_query?
      ActiveSupport::IsolatedExecutionState[:active_record_instrumenter].class.name ==
        "ActiveRecord::FutureResult::EventBuffer"
    end
  end
end
