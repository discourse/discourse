# frozen_string_literal: true

module Discourse
  class PerformanceFormatter
    if defined?(RSpec::Core::Formatters)
      RSpec::Core::Formatters.register(self, :example_passed, :example_failed, :example_pending)
    end

    @active = false

    class << self
      def enabled?
        @active || ENV["DISCOURSE_RSPEC_PERF"] == "1"
      end

      def activate!
        @active = true
      end

      def summarize(timing)
        timing ||= {}
        sql = items(timing, :sql)
        redis = items(timing, :redis)
        net = items(timing, :net)
        { totals: { sql: totals(sql), redis: totals(redis), net: totals(net) }, sql:, redis:, net: }
      end

      def assemble(test_summary, request_groups)
        all_totals = [test_summary[:totals], *request_groups.map { |group| group[:totals] }]
        {
          totals: combine_totals(all_totals),
          sql: test_summary[:sql],
          redis: test_summary[:redis],
          net: test_summary[:net],
          requests: request_groups,
        }
      end

      private

      def items(timing, key)
        timing[key]&.dig(:items) || []
      end

      def totals(items)
        { calls: items.size, duration_ms: items.sum { |item| item[:duration_ms] || 0.0 }.to_f }
      end

      def combine_totals(all_totals)
        %i[sql redis net].each_with_object({}) do |key, result|
          result[key] = {
            calls: all_totals.sum { |category_totals| category_totals[key][:calls] },
            duration_ms:
              all_totals.sum { |category_totals| category_totals[key][:duration_ms] }.to_f,
          }
        end
      end
    end

    def initialize(output)
      @output = output
      self.class.activate!
      MethodProfiler.itemize_enabled = true
    end

    def example_passed(notification)
      write(notification.example)
    end

    def example_failed(notification)
      write(notification.example)
    end

    def example_pending(notification)
      write(notification.example)
    end

    private

    def write(example)
      @output.puts(JSON.generate(Serializer.serialize(example, example.metadata[:perf])))
    rescue StandardError => error
      @output.puts(
        JSON.generate(
          example_id: example.location_rerun_argument,
          status: example.execution_result.status.to_s,
          error: {
            class: error.class.name,
            message: error.message.to_s,
          },
        ),
      )
    end

    module Capture
      def self.measure
        MethodProfiler.ensure_discourse_instrumentation!
        MethodProfiler.start
        yield
        PerformanceFormatter.summarize(MethodProfiler.stop)
      end

      def self.collect_requests
        groups = []
        logger = ->(env, data) do
          group = RequestGroup.build(env, data)
          groups << group if group
        rescue StandardError
          nil
        end
        Middleware::RequestTracker.register_detailed_request_logger(logger)
        yield
        groups
      ensure
        Middleware::RequestTracker.unregister_detailed_request_logger(logger)
      end
    end

    module RequestGroup
      def self.build(env, data)
        return if data[:is_background]
        { method: env["REQUEST_METHOD"], path: env["PATH_INFO"], status: data[:status] }.merge(
          PerformanceFormatter.summarize(data[:timing]),
        )
      end
    end

    module Serializer
      def self.serialize(example, perf)
        perf = normalize(perf)
        execution = example.execution_result
        result = {
          example_id: example.location_rerun_argument,
          description: example.full_description,
          location: example.location,
          status: execution.status.to_s,
          totals: perf[:totals],
          sql: perf[:sql],
          redis: perf[:redis],
          net: perf[:net],
          requests: perf[:requests],
        }
        result[:error] = error_for(execution.exception) if execution.exception
        result
      end

      def self.error_for(exception)
        {
          class: exception.class.name,
          message: exception.message.to_s,
          backtrace: Array(exception.backtrace).first(10),
        }
      end

      def self.normalize(perf)
        return PerformanceFormatter.summarize(nil).merge(requests: []) if perf.blank?
        perf.deep_symbolize_keys
      end
    end
  end
end
