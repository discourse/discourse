# frozen_string_literal: true

require "rspec/core"
require "timeout"
require_relative "work_queue"

module TurboTests
  module LeasedExamples
    class Completions
      attr_reader :ids

      def initialize
        @ids = []
      end

      def example_passed(notification)
        @ids << notification.example.id
      end

      alias example_failed example_passed
      alias example_pending example_passed
    end

    def run_specs(example_groups)
      socket_path = ENV["DISCOURSE_TURBO_RSPEC_WORK_QUEUE"]
      return super unless socket_path

      groups = example_groups.group_by { |group| WorkQueue.origin(group.id) }
      manifest =
        groups.transform_values do |roots|
          roots.flat_map { |root| root.descendants.flat_map(&:filtered_examples).map(&:id) }.sort
        end
      example_count = @world.example_count(example_groups)
      socket = UNIXSocket.new(socket_path)
      exchange =
        lambda do |message|
          Timeout.timeout(150) do
            socket.puts(JSON.generate(message))
            line = socket.gets or raise "Work queue disconnected"
            JSON.parse(line)
          end
        end
      ready = exchange.call(type: "ready", worker: ENV.fetch("TEST_ENV_NUMBER"), manifest: manifest)
      completions = Completions.new
      @configuration.reporter.register_listener(
        completions,
        :example_passed,
        :example_pending,
        :example_failed,
      )
      passed =
        @configuration
          .reporter
          .report(example_count) do |reporter|
            @configuration.with_suite_hooks do
              if example_count == 0 && @configuration.fail_if_no_examples
                false
              elsif ready.fetch("type") == "stop"
                false
              else
                success = true
                loop do
                  reply =
                    exchange.call(
                      type: "next",
                      completed: completions.ids,
                      cancelled: !!@world.wants_to_quit,
                    )
                  completions.ids.clear
                  break if reply.fetch("type") == "stop"
                  raise "Unexpected work queue response" unless reply["type"] == "file"
                  groups
                    .fetch(reply.fetch("file"))
                    .each { |group| success = group.run(reporter) && success }
                end
                success && !@world.wants_to_quit
              end
            end
          end
      status = exit_code(passed)
      exchange.call(
        type: "finish",
        exit_code: status,
        non_example_failure: !!@world.non_example_failure,
      )
      status
    rescue StandardError => error
      @configuration.reporter.notify_non_example_exception(
        error,
        "Dynamic work distribution failed",
      )
      exit_code(false)
    ensure
      socket&.close
    end

    private

    def persist_example_statuses
      return super unless ENV["DISCOURSE_TURBO_RSPEC_WORK_QUEUE"]
      return if @configuration.dry_run
      path = @configuration.example_status_persistence_file_path
      return unless path

      examples = @world.all_examples.select { |example| example.execution_result.status }
      RSpec::Core::ExampleStatusPersister.persist(examples, path)
    rescue SystemCallError => error
      RSpec.warning(
        "Could not write executed example statuses to #{path}: #{error.inspect}",
        call_site: nil,
      )
    end
  end
end

RSpec::Core::Runner.prepend(TurboTests::LeasedExamples) if ENV["DISCOURSE_TURBO_RSPEC_WORK_QUEUE"]
