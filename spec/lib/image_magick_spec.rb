# frozen_string_literal: true

require "image_magick"

RSpec.describe ImageMagick do
  describe ".magick" do
    it "emits one monotonic wall-clock measurement for a successful command" do
      monotonic_times = [10.0, 11.25]
      allow(Process).to receive(
        :clock_gettime,
      ).and_wrap_original do |original, clock_id, *arguments|
        if clock_id == Process::CLOCK_MONOTONIC &&
             caller_locations.any? { |location|
               location.path.end_with?("lib/image_processing/instrumentation.rb")
             }
          monotonic_times.shift
        else
          original.call(clock_id, *arguments)
        end
      end
      allow(Discourse::SafeExec).to receive(:capture).and_return("image output")

      events =
        DiscourseEvent.track_events(:image_processing_finished) do
          expect(described_class.magick("--version", operation: :custom_image_operation)).to eq(
            "image output",
          )
        end

      expect(events.size).to eq(1)
      payload = events.first[:params].first
      expect(payload.except(:duration_seconds)).to eq(
        operation: "custom_image_operation",
        result: "success",
      )
      expect(payload[:duration_seconds]).to eq(1.25)
      expect(monotonic_times).to be_empty
    end

    it "emits one measurement with a bounded result for every command failure" do
      failure_cases = {
        "wall_timeout" => [
          Discourse::Utils::CommandError.new(
            "timed out",
            status: instance_double(Process::Status, signaled?: false, exited?: true),
          ),
          0,
        ],
        "cpu_limit" => [
          Discourse::Utils::CommandError.new(
            "CPU limit",
            status:
              instance_double(Process::Status, signaled?: true, termsig: Signal.list.fetch("XCPU")),
          ),
          10,
        ],
        "file_size_limit" => [
          Discourse::Utils::CommandError.new(
            "file size limit",
            status:
              instance_double(Process::Status, signaled?: true, termsig: Signal.list.fetch("XFSZ")),
          ),
          10,
        ],
        "signal" => [
          Discourse::Utils::CommandError.new(
            "killed",
            status:
              instance_double(Process::Status, signaled?: true, termsig: Signal.list.fetch("KILL")),
          ),
          10,
        ],
        "nonzero_exit" => [
          Discourse::Utils::CommandError.new(
            "failed",
            status: instance_double(Process::Status, signaled?: false, exited?: true),
          ),
          10,
        ],
        "exception" => [Errno::ENOENT.new("magick"), 10],
      }

      observed_results =
        failure_cases.map do |expected_result, (error, timeout_seconds)|
          allow(Discourse::SafeExec).to receive(:capture).and_raise(error)

          events =
            DiscourseEvent.track_events(:image_processing_finished) do
              expect {
                described_class.magick(
                  "input.png",
                  "output.png",
                  operation: :optimized_image_resize,
                  timeout: timeout_seconds,
                )
              }.to raise_error(error.class)
            end

          expect(events.size).to eq(1)
          payload = events.first[:params].first
          expect(payload.except(:duration_seconds)).to eq(
            operation: "optimized_image_resize",
            result: expected_result,
          )
          expect(payload[:duration_seconds]).to be >= 0
          payload[:result]
        end

      expect(observed_results).to eq(failure_cases.keys)
    end

    it "rejects non-Symbol operations" do
      events =
        DiscourseEvent.track_events(:image_processing_finished) do
          expect { described_class.magick("--version", operation: "dynamic") }.to raise_error(
            ArgumentError,
            /operation must be a Symbol/,
          )
        end

      expect(events).to be_empty
    end
  end
end
