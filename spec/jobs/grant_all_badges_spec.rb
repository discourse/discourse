# frozen_string_literal: true

RSpec.describe Jobs::GrantAllBadges do
  it "schedules a GrantBadge job for each badge" do
    described_class.new.execute({})

    expect(Jobs::GrantBadge.jobs.size).to eq(Badge.enabled.size)
  end
end
