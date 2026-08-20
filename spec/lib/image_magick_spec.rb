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
          expect(described_class.magick("--version", operation: :letter_avatar_version)).to eq(
            "image output",
          )
        end

      expect(events.size).to eq(1)
      payload = events.first[:params].first
      expect(payload.except(:duration_seconds)).to eq(
        operation: "letter_avatar_version",
        success: true,
        error_reason: nil,
      )
      expect(payload[:duration_seconds]).to eq(1.25)
      expect(monotonic_times).to be_empty
    end

    it "emits one measurement with a bounded reason for every command failure" do
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

      observed_reasons =
        failure_cases.map do |expected_reason, (error, timeout_seconds)|
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
            success: false,
            error_reason: expected_reason,
          )
          expect(payload[:duration_seconds]).to be >= 0
          payload[:error_reason]
        end

      expect(observed_reasons).to eq(failure_cases.keys)
    end

    it "rejects operations outside the stable operation set" do
      events =
        DiscourseEvent.track_events(:image_processing_finished) do
          expect { described_class.magick("--version", operation: :unknown) }.to raise_error(
            ArgumentError,
            /unknown image-processing operation/,
          )
        end

      expect(events).to be_empty
    end
  end
end
