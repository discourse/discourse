# frozen_string_literal: true

require "rails_helper"

describe Jobs::Chat::AutoJoinChannelBatch do
  it "can successfully queue this job" do
    expect {
      Jobs.enqueue(
        described_class,
        channel_id: Fabricate(:chat_channel).id,
        start_user_id: 0,
        end_user_id: 10,
      )
    }.to change(Jobs::Chat::AutoJoinChannelBatch.jobs, :size).by(1)
  end

  context "when contract fails" do
    before { Jobs.run_immediately! }

    it "logs an error" do
      Rails.logger.expects(:error).with(regexp_matches(/Channel can't be blank/)).at_least_once

      Jobs.enqueue(described_class)
    end
  end

  context "when model is not found" do
    before { Jobs.run_immediately! }

    it "logs an error" do
      Rails.logger.expects(:error).with("Channel not found (id=-999)").at_least_once

      Jobs.enqueue(described_class, channel_id: -999, start_user_id: 1, end_user_id: 2)
    end
  end
end
