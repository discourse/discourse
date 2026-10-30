# frozen_string_literal: true

RSpec.describe Jobs::SchedulePollClosures do
  describe "#execute" do
    it "schedules polls that close soon" do
      freeze_time(Time.zone.now.beginning_of_minute)
      poll = Fabricate(:poll)
      poll.update_columns(close_at: 20.minutes.from_now)

      described_class.new.execute({})

      expect_job_enqueued(
        job: :close_poll,
        args: {
          poll_id: poll.id,
          close_at: poll.close_at.to_i,
        },
        at: poll.close_at,
      )
    end
  end
end
