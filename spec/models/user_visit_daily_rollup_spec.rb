# frozen_string_literal: true

RSpec.describe UserVisitDailyRollup do
  fab!(:visitor, :user)

  before { freeze_time(Time.zone.local(2026, 7, 23, 12)) }

  describe ".fetch" do
    it "returns existing rows in date order and omits dates without rows" do
      described_class.create!(date: 2.days.ago, dau: 1, mau: 3)
      described_class.create!(date: Time.zone.today, dau: 2, mau: 4)

      rows = described_class.fetch(start_date: 2.days.ago, end_date: Time.zone.today)

      expect(rows).to eq(
        [
          { "date" => 2.days.ago.to_date, "dau" => 1, "mau" => 3 },
          { "date" => Time.zone.today, "dau" => 2, "mau" => 4 },
        ],
      )
    end
  end

  describe ".aggregate" do
    it "stores the same daily values as the established calculation" do
      visitor.user_visits.create!(visited_at: Time.zone.today)
      historical_visitor = Fabricate(:user)
      historical_visitor.user_visits.create!(visited_at: 10.days.ago)
      expected = UserVisit.count_by_active_users(10.days.ago, Time.zone.today)

      described_class.aggregate(start_date: 10.days.ago, end_date: Time.zone.today)

      expect(described_class.fetch(start_date: 10.days.ago, end_date: Time.zone.today)).to eq(
        expected,
      )
    end

    it "keeps existing report data when a refresh fails" do
      existing = described_class.create!(date: Time.zone.today, dau: 3, mau: 4)
      described_class.stubs(:insert_all!).raises(ActiveRecord::StatementInvalid)
      visitor.user_visits.create!(visited_at: Time.zone.today)

      expect do
        described_class.aggregate(start_date: Time.zone.today, end_date: Time.zone.today)
      end.to raise_error(ActiveRecord::StatementInvalid)

      expect(existing.reload).to have_attributes(dau: 3, mau: 4)
    end
  end
end
