# frozen_string_literal: true

require "image_processing/command"

RSpec.describe ImageProcessing::Command do
  describe ".capture" do
    def capture_result(
      status:,
      timed_out: false,
      output_truncated: false,
      elapsed_seconds: 1.25,
      cpu_seconds: 0.75,
      max_rss_bytes: 16.megabytes
    )
      resource_usage =
        Landlock::ResourceUsage.new(
          user_seconds: cpu_seconds / 2,
          system_seconds: cpu_seconds / 2,
          max_rss_bytes:,
        )

      Landlock::CaptureResult.new(
        stdout: "image output",
        stderr: "",
        status:,
        timed_out:,
        output_truncated:,
        elapsed_seconds:,
        resource_usage:,
      )
    end

    before { allow(Landlock).to receive(:supported?).and_return(true) }

    it "emits measurements from a completed Landlock result" do
      status = instance_double(Process::Status, signaled?: false, exited?: true, exitstatus: 0)
      result = capture_result(status:)
      allow(Landlock).to receive(:capture).and_return(result)

      event =
        DiscourseEvent.track(:image_processing_finished) do
          expect(described_class.capture("image-tool", operation: :optimized_image_resize)).to eq(
            "image output",
          )
        end

      expect(event[:params].first).to eq(
        operation: "optimized_image_resize",
        success: true,
        error_reason: "none",
        duration_seconds: 1.25,
        cpu_seconds: 0.75,
        max_rss_bytes: 16.megabytes,
      )
    end

    it "classifies every established failure reason" do
      failure_cases = {
        "wall_timeout" =>
          capture_result(status: instance_double(Process::Status, exited?: false), timed_out: true),
        "output_limit" =>
          capture_result(
            status: instance_double(Process::Status, exited?: false),
            output_truncated: true,
          ),
        "cpu_limit" =>
          capture_result(
            status:
              instance_double(
                Process::Status,
                signaled?: true,
                termsig: Signal.list.fetch("XCPU"),
                exited?: false,
              ),
          ),
        "file_size_limit" =>
          capture_result(
            status:
              instance_double(
                Process::Status,
                signaled?: true,
                termsig: Signal.list.fetch("XFSZ"),
                exited?: false,
              ),
          ),
        "signal" =>
          capture_result(
            status:
              instance_double(
                Process::Status,
                signaled?: true,
                termsig: Signal.list.fetch("KILL"),
                exited?: false,
              ),
          ),
        "nonzero_exit" =>
          capture_result(
            status:
              instance_double(Process::Status, signaled?: false, exited?: true, exitstatus: 1),
          ),
      }

      observed_reasons =
        failure_cases.values.map do |result|
          allow(Landlock).to receive(:capture).and_return(result)

          event =
            DiscourseEvent.track(:image_processing_finished) do
              expect {
                described_class.capture("image-tool", operation: :optimized_image_crop)
              }.to raise_error(Discourse::Utils::CommandError)
            end

          payload = event[:params].first
          expect(payload[:success]).to eq(false)
          expect(payload.values_at(:duration_seconds, :cpu_seconds, :max_rss_bytes)).to eq(
            [1.25, 0.75, 16.megabytes],
          )
          payload[:error_reason]
        end

      expect(observed_reasons).to eq(failure_cases.keys)
    end

    it "emits no event when SafeExec uses its fallback" do
      allow(Landlock).to receive(:supported?).and_return(false)
      allow(Discourse::Utils).to receive(:execute_command).and_return("image output")

      events =
        DiscourseEvent.track_events(:image_processing_finished) do
          described_class.capture("image-tool", operation: :upload_format_conversion)
        end

      expect(events).to be_empty
    end

    it "does not let instrumentation failures interrupt the command" do
      status = instance_double(Process::Status, signaled?: false, exited?: true, exitstatus: 0)
      allow(Landlock).to receive(:capture).and_return(capture_result(status:))
      allow(DiscourseEvent).to receive(:trigger).and_raise("instrumentation failed")

      expect(described_class.capture("image-tool", operation: :topic_og_render)).to eq(
        "image output",
      )
    end

    it "rejects operations outside the stable operation set" do
      expect { described_class.capture("image-tool", operation: :unknown) }.to raise_error(
        ArgumentError,
        /unknown image-processing operation/,
      )
    end
  end
end
