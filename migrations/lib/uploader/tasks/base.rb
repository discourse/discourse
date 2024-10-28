# frozen_string_literal: true

require "etc"
require "colored2"

module Migrations::Uploader
  module Tasks
    class Base
      class NotImplementedError < StandardError
      end

      TRANSACTION_SIZE = 1000
      QUEUE_SIZE = 1000
      DEFAULT_THREAD_FACTOR = 1.5

      attr_reader :uploads_db,
                  :intermediate_db,
                  :settings,
                  :work_queue,
                  :status_queue,
                  :discourse_store,
                  :error_count,
                  :current_count,
                  :missing_count,
                  :skipped_count

      def initialize(databases, settings)
        @uploads_db = databases[:uploads_db]
        @intermediate_db = databases[:intermediate_db]

        @settings = settings

        @work_queue = SizedQueue.new(QUEUE_SIZE)
        @status_queue = SizedQueue.new(QUEUE_SIZE)
        @discourse_store = Discourse.store

        @error_count = 0
        @current_count = 0
        @missing_count = 0
        @skipped_count = 0
      end

      def run!
        raise NotImplementedError
      end

      def self.run!(databases, settings)
        new(databases, settings).run!
      end

      protected

      def handle_status_update
        raise NotImplementedError
      end

      def enqueue_jobs
        raise NotImplementedError
      end

      def instantiate_task_resource
        {}
      end

      def start_status_thread
        Thread.new do
          while !(result = status_queue.pop).nil?
            handle_status_update(result)
            log_status
          end
        end
      end

      def start_consumer_threads
        thread_count.times.map { |index| consumer_thread(index) }
      end

      def consumer_thread(index)
        Thread.new do
          Thread.current.name = "worker-#{index}"
          resource = instantiate_task_resource

          while (row = work_queue.pop)
            process_upload(row, resource)
          end
        end
      end

      def start_producer_thread
        Thread.new { enqueue_jobs }
      end

      def thread_count
        @thread_count ||= calculate_thread_count
      end

      def add_multisite_prefix(path)
        return path if !Rails.configuration.multisite

        File.join("uploads", RailsMultisite::ConnectionManagement.current_db, path)
      end

      def file_exists?(path)
        if discourse_store.external?
          discourse_store.object_from_path(path).exists?
        else
          File.exist?(File.join(discourse_store.public_dir, path))
        end
      end

      def with_retries(max: 3)
        count = 0

        loop do
          result = yield
          break result if result

          count += 1
          break nil if count >= max

          sleep(calculate_backoff(count))
        end
      end

      private

      def calculate_backoff(retry_count)
        0.25 * retry_count
      end

      def calculate_thread_count
        base = Etc.nprocessors
        thread_count_factor = settings.fetch(:thread_count_factor, DEFAULT_THREAD_FACTOR)
        store_factor = discourse_store.external? ? 2 : 1

        (base * thread_count_factor * store_factor).to_i
      end
    end
  end
end
