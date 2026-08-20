# frozen_string_literal: true

require "image_magick"

RSpec.describe ImageMagick do
  describe ".magick" do
    it "bypasses instrumentation and validation by default" do
      instrumentation_clock_reads = 0
      allow(Process).to receive(
        :clock_gettime,
      ).and_wrap_original do |original, clock_id, *arguments|
        if caller_locations.any? { |location|
             location.path.end_with?("lib/image_processing/instrumentation.rb")
           }
          instrumentation_clock_reads += 1
        end
        original.call(clock_id, *arguments)
      end
      allow(Discourse::SafeExec).to receive(:capture).and_return("image output")

      events =
        DiscourseEvent.track_events(:image_processing_finished) do
          expect(described_class.magick("--version", operation: "dynamic")).to eq("image output")
        end

      expect(SiteSetting.instrument_image_processing).to eq(false)
      expect(events).to be_empty
      expect(instrumentation_clock_reads).to eq(0)
    end

    it "emits one monotonic wall-clock measurement for a successful command" do
      SiteSetting.instrument_image_processing = true
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
        success: true,
      )
      expect(payload[:duration_seconds]).to eq(1.25)
      expect(monotonic_times).to be_empty
    end

    it "emits one unsuccessful measurement and preserves a command failure" do
      SiteSetting.instrument_image_processing = true
      error = RuntimeError.new("command failed")
      allow(Discourse::SafeExec).to receive(:capture).and_raise(error)

      events =
        DiscourseEvent.track_events(:image_processing_finished) do
          expect {
            described_class.magick("input.png", "output.png", operation: :optimized_image_resize)
          }.to raise_error { |raised_error| expect(raised_error).to equal(error) }
        end

      expect(events.size).to eq(1)
      payload = events.first[:params].first
      expect(payload.except(:duration_seconds)).to eq(
        operation: "optimized_image_resize",
        success: false,
      )
      expect(payload[:duration_seconds]).to be_a(Numeric)
    end

    it "rejects non-Symbol operations" do
      SiteSetting.instrument_image_processing = true
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
