# frozen_string_literal: true

RSpec.describe Jobs::GrantBadge do
  subject(:job) { described_class.new }

  let(:scheduled_jobs) { Sidekiq::ScheduledSet.new }

  before { scheduled_jobs.clear }

  it "schedules a EnsureBadgeConsistency job" do
    Sidekiq::Testing.disable! do
      badge_ids = Badge.enabled.pluck(:id)

      threads =
        badge_ids[...3].map do |badge_id|
          Thread.new { described_class.new.execute({ badge_id: badge_id }) }
        end

      # EnsureBadgeConsistency may be scheduled or not at this point, but it must
      # not be scheduled more than once
      expect(scheduled_jobs.size).to be <= 1

      threads.each(&:join)

      expect(scheduled_jobs.size).to eq(1)
    end
  end
end
