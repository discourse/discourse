# frozen_string_literal: true

RSpec.describe Jobs::WarmDashboardReports do
  fab!(:admin)

  before do
    Discourse.cache.clear
    SiteSetting.dashboard_improvements = true
    admin.update!(last_seen_at: 1.hour.ago)
  end

  def warmed_signups
    Report.find_cached(
      "signups",
      facets: %i[prev_period],
      start_date: 29.days.ago.to_date.beginning_of_day,
      end_date: Time.zone.now.to_date.end_of_day,
    )
  end

  describe "#execute" do
    it "populates the report cache for the dashboard's default window" do
      described_class.new.execute({})

      expect(warmed_signups).to be_present
    end

    it "warms when only a moderator has been seen recently" do
      admin.update!(last_seen_at: 30.days.ago)
      Fabricate(:moderator, last_seen_at: 1.hour.ago)

      described_class.new.execute({})

      expect(warmed_signups).to be_present
    end

    it "skips warming when the new dashboard is disabled" do
      SiteSetting.dashboard_improvements = false

      described_class.new.execute({})

      expect(warmed_signups).to be_nil
    end

    it "skips warming when no staff member has been seen recently" do
      admin.update!(last_seen_at: 30.days.ago)

      described_class.new.execute({})

      expect(warmed_signups).to be_nil
    end
  end
end
