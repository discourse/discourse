# frozen_string_literal: true

RSpec.describe ::Jobs::Heartbeat do
  after { Discourse.disable_readonly_mode }

  it "still enqueues heartbeats in readonly mode" do
    freeze_time 1.week.from_now

    Discourse.enable_readonly_mode

    Sidekiq::Testing.inline! do
      ::Jobs::Heartbeat.new.perform(nil)
      expect(::Jobs::RunHeartbeat.last_heartbeat).to eq(Time.now.to_i)
    end
  end
end
