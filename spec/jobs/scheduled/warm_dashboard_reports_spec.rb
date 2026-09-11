# frozen_string_literal: true

RSpec.describe Jobs::WarmDashboardReports do
  fab!(:admin)

  let(:cache) do
    Class
      .new(Cache) do
        attr_reader :report_writes

        def initialize
          super
          @report_writes = []
        end

        def write(name, value, **options)
          super.tap { @report_writes << value if name.start_with?("reports:") }
        end
      end
      .new
  end

  before do
    Discourse.stubs(:cache).returns(cache)
    Discourse.cache.clear
    SiteSetting.dashboard_improvements = true
    admin.update!(last_seen_at: 1.hour.ago)
  end

  def warmed_signups(guardian: admin.guardian, offset: 0)
    end_date = Time.zone.now.to_date + offset

    Report.find_cached(
      "signups",
      guardian: guardian,
      facets: %i[prev_period],
      start_date: (end_date - 29).beginning_of_day,
      end_date: end_date.end_of_day,
    )
  end

  describe "#execute" do
    it "generates one shared set of reports regardless of the number of active staff" do
      described_class.new.execute({})
      single_staff_types = cache.report_writes.map { |report| report[:type] }.tally
      cache.clear
      cache.report_writes.clear
      moderator = Fabricate(:moderator, last_seen_at: 1.hour.ago)
      Fabricate(:admin, last_seen_at: 1.hour.ago)

      described_class.new.execute({})

      expect(single_staff_types).to eq(
        "signups" => 3,
        "dau_by_mau" => 3,
        "new_contributors" => 3,
        "daily_engaged_users" => 3,
        "trust_level_pipeline" => 3,
      )
      expect(cache.report_writes.map { |report| report[:type] }.tally).to eq(single_staff_types)
      (-1..1).each do |offset|
        expect(warmed_signups(offset: offset)).to be_present
        expect(warmed_signups(guardian: moderator.guardian, offset: offset)).to eq(
          warmed_signups(offset: offset),
        )
      end
    end

    it "warms when only a moderator has been seen recently" do
      admin.update!(last_seen_at: 30.days.ago)
      moderator = Fabricate(:moderator, last_seen_at: 1.hour.ago)

      described_class.new.execute({})

      expect(warmed_signups(guardian: moderator.guardian)).to be_present
      expect(warmed_signups).to eq(warmed_signups(guardian: moderator.guardian))
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
