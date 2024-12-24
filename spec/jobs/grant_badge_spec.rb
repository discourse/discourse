# frozen_string_literal: true

RSpec.describe Jobs::GrantBadge do
  subject(:job) { described_class.new }

  it "schedules a EnsureBadgeConsistency job" do
    # Keep the test fast by only enabling 2 badges
    badge_ids = Badge.enabled.limit(2).pluck(:id)
    Badge.where.not(id: badge_ids).update_all(enabled: false)

    # Ensures it starts a new batch of GrantBadge jobs
    Jobs::GrantAllBadges.new.execute({})
    expect(Jobs::GrantBadge.jobs.map { |job| job["args"][0]["badge_id"] }).to eq(badge_ids)

    # First GrantBadge job should not enqueue EnsureBadgeConsistency
    Jobs::GrantBadge.new.execute(badge_id: badge_ids.first)
    expect(Jobs::EnsureBadgeConsistency.jobs).to be_empty

    # Last GrantBadge job should enqueue EnsureBadgeConsistency
    Jobs::GrantBadge.new.execute(badge_id: badge_ids.last)
    expect(Jobs::EnsureBadgeConsistency.jobs).not_to be_empty
  end
end
