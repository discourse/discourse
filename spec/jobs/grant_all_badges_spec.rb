# frozen_string_literal: true

RSpec.describe Jobs::GrantAllBadges do
  it "schedules a GrantBadge job for each badge" do
    described_class.new.execute({})

    expect(Jobs::GrantBadge.jobs.size).to eq(Badge.enabled.size)
  end

  it "schedules a EnsureBadgeConsistency job after all GrantBadge jobs" do
    Jobs.run_immediately!

    Jobs::EnsureBadgeConsistency.any_instance.expects(:execute).once

    described_class.new.execute({})
  end
end
