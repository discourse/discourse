# frozen_string_literal: true

RSpec.describe Jobs::WarmDashboardReports do
  fab!(:admin)

  before do
    Discourse.cache.clear
    SiteSetting.dashboard_improvements = true
    admin.update!(last_seen_at: 1.hour.ago)
  end

  def warmed_signups(guardian: admin.guardian)
    Report.find_cached(
      "signups",
      guardian: guardian,
      facets: %i[prev_period],
      start_date: 29.days.ago.to_date.beginning_of_day,
      end_date: Time.zone.now.to_date.end_of_day,
    )
  end

  describe "#execute" do
    it "populates each recently active staff reader's cache for the default window" do
      moderator = Fabricate(:moderator, last_seen_at: 1.hour.ago)

      described_class.new.execute({})

      expect(warmed_signups).to be_present
      expect(warmed_signups(guardian: moderator.guardian)).to be_present
      expect(warmed_signups(guardian: Discourse.system_user.guardian)).to be_nil
    end

    it "warms when only a moderator has been seen recently" do
      admin.update!(last_seen_at: 30.days.ago)
      moderator = Fabricate(:moderator, last_seen_at: 1.hour.ago)

      described_class.new.execute({})

      expect(warmed_signups(guardian: moderator.guardian)).to be_present
      expect(warmed_signups).to be_nil
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
