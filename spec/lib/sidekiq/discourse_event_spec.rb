# frozen_string_literal: true

RSpec.describe Sidekiq::DiscourseEvent do
  describe "#call" do
    it "should trigger the `sidekiq_job_ran` discourse event when successfully executing the block" do
      called = false

      events =
        DiscourseEvent.track_events(:sidekiq_job_ran) do
          described_class
            .new
            .call("SomeClass", { some_key: "some_value" }, "some_queue_name") { called = true }
        end

      expect(called).to eq(true)
      expect(events.length).to eq(1)

      event = events.first

      expect(event[:event_name]).to eq(:sidekiq_job_ran)
      expect(event[:params][0]).to eq("SomeClass")
      expect(event[:params][1]).to eq({ some_key: "some_value" })
      expect(event[:params][2]).to eq("some_queue_name")
      expect(event[:params][3]).to be_a(Float)
    end

    it "should trigger `sidekiq_job_error` discourse event when an error occurs while executing the block" do
      called = false

      events =
        DiscourseEvent.track_events(:sidekiq_job_error) do
          expect do
            described_class
              .new
              .call("SomeClass", { some_key: "some_value" }, "some_queue_name") do
                called = true
                raise StandardError, "Boom!"
              end
          end.to raise_error(StandardError, "Boom!")
        end

      expect(called).to eq(true)
      expect(events.length).to eq(1)

      event = events.first

      expect(event[:event_name]).to eq(:sidekiq_job_error)
      expect(event[:params][0]).to eq("SomeClass")
      expect(event[:params][1]).to eq({ some_key: "some_value" })
      expect(event[:params][2]).to eq("some_queue_name")
      expect(event[:params][3]).to be_a(Float)
    end
  end
end
