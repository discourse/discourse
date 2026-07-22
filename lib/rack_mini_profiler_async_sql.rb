# frozen_string_literal: true

module RackMiniProfilerAsyncSql
  def self.install
    return if @installed
    return if !defined?(Rack::MiniProfiler)

    suppress_adapter_recording_during_async_queries

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

    @installed = true
  end

  def self.suppress_adapter_recording_during_async_queries
    SqlPatches.singleton_class.prepend(SqlPatchesAsyncSuppression)
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
