# frozen_string_literal: true

RSpec.describe Jobs::MaintainUserVisitDailyRollups do
  subject(:job) { described_class.new }

  fab!(:recent_visitor, :user)
  fab!(:historical_visitor, :user)

  before { freeze_time(Time.zone.local(2026, 7, 23, 12)) }

  describe "#execute" do
    it "aggregates the complete visit history on its first run" do
      recent_visitor.user_visits.create!(visited_at: Time.zone.today)
      historical_visitor.user_visits.create!(visited_at: 10.days.ago)

      job.execute({})

      expect(UserVisitDailyRollup.order(:date).pluck(:date, :dau, :mau)).to eq(
        [[10.days.ago.to_date, 1, 1], [Time.zone.today, 1, 2]],
      )
    end

    it "refreshes only yesterday and today after the initial aggregation" do
      recent_visitor.user_visits.create!(visited_at: Time.zone.today)
      historical_visitor.user_visits.create!(visited_at: 10.days.ago)
      job.execute({})
      late_historical_visitor = Fabricate(:user)
      late_historical_visitor.user_visits.create!(visited_at: 40.days.ago)
      another_recent_visitor = Fabricate(:user)
      another_recent_visitor.user_visits.create!(visited_at: Time.zone.today)

      job.execute({})

      expect(UserVisitDailyRollup.where(date: 40.days.ago).exists?).to eq(false)
      expect(UserVisitDailyRollup.find_by(date: Time.zone.today)).to have_attributes(dau: 2, mau: 3)
    end

    it "fills active dates since the most recent rollup" do
      Fabricate(:user_visit_daily_rollup, date: 3.days.ago)
      historical_visitor.user_visits.create!(visited_at: 2.days.ago)
      recent_visitor.user_visits.create!(visited_at: Time.zone.today)

      job.execute({})

      expect(UserVisitDailyRollup.order(:date).pluck(:date)).to eq(
        [3.days.ago.to_date, 2.days.ago.to_date, Time.zone.today],
      )
    end
  end
end
