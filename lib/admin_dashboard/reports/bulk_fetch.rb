# frozen_string_literal: true

module AdminDashboard
  module Reports
    class BulkFetch
      FETCH_FAILED = :fetch_failed

      MAX_CONCURRENT_FETCHES = 4

      class << self
        def call(items:, filters:, guardian:)
          payloads = fetch_in_parallel(items, guardian:, filters:)

          results =
            items
              .zip(payloads)
              .map do |item, payload|
                failed = payload == FETCH_FAILED
                errored = failed || (payload.is_a?(Hash) && payload[:error].present?)
                {
                  source: item[:source],
                  identifier: item[:identifier],
                  key: item_key(item),
                  data: failed ? nil : payload,
                  error: errored,
                }
              end

          { items: results }
        end

        def pool_size
          available = [ActiveRecord::Base.connection_pool.size - 1, 1].max
          [MAX_CONCURRENT_FETCHES, available].min
        end

        def thread_pool
          @thread_pool ||=
            Scheduler::ThreadPool.new(min_threads: 0, max_threads: pool_size, idle_time: 30)
        end

        def fetch_item(item, guardian:, filters:)
          provider = AdminDashboard::Reports::Registry.provider_for(item[:source])
          return nil if provider.nil?

          provider.fetch_many([item[:identifier]], guardian:, filters:)[item[:identifier]]
        end

        def fetch_in_parallel(items, guardian:, filters:)
          return [] if items.empty?

          queue = Queue.new

          items.each_with_index do |item, index|
            thread_pool.post do
              ActiveRecord::Base.with_connection(prevent_permanent_checkout: true) do
                queue << [index, fetch_item(item, guardian:, filters:)]
              end
            rescue StandardError => e
              Discourse.warn_exception(
                e,
                message: "Failed to fetch admin dashboard report",
                env: {
                  source: item[:source],
                  identifier: item[:identifier],
                },
              )
              queue << [index, FETCH_FAILED]
            end
          end

          results = Array.new(items.size)
          items.size.times do
            index, result = queue.pop
            results[index] = result
          end
          results
        end

        private :fetch_in_parallel

        def item_key(item)
          "#{item[:source]}:#{item[:identifier]}"
        end

        private :item_key
      end

      private_class_method :fetch_item
    end
  end
end
