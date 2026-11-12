# frozen_string_literal: true

RSpec.describe Jobs::MaintainCategoryActivityDailyRollups do
  fab!(:category)

  before { freeze_time(Time.zone.local(2026, 4, 28, 12)) }

  it "rolls up the whole history on the first run" do
    Fabricate(:topic, category: category, created_at: 200.days.ago)
    Fabricate(:topic, category: category, created_at: 1.day.ago)

    described_class.new.execute

    expect(CategoryActivityDailyRollup.pluck(:date)).to contain_exactly(
      200.days.ago.to_date,
      1.day.ago.to_date,
    )
  end

  it "recalculates the recent window once history has been rolled up" do
    Fabricate(:topic, category: category, created_at: 1.day.ago)
    stale =
      Fabricate(:category_activity_daily_rollup, category: category, date: 1.day.ago, topics: 99)

    described_class.new.execute

    expect(CategoryActivityDailyRollup.find_by(date: 1.day.ago.to_date).topics).to eq(1)
    expect { stale.reload }.to raise_error(ActiveRecord::RecordNotFound)
  end

  it "leaves history outside the recent window to the daily rebuild" do
    Fabricate(:topic, category: category, created_at: 200.days.ago)
    Fabricate(:category_activity_daily_rollup, category: category, date: 1.day.ago)

    described_class.new.execute

    expect(CategoryActivityDailyRollup.exists?(date: 200.days.ago.to_date)).to eq(false)
  end

  it "does nothing on a site whose only topics are excluded from the rollup" do
    Fabricate(:topic, category: category, created_at: 200.days.ago, deleted_at: Time.zone.now)
    Fabricate(:private_message_topic, created_at: 200.days.ago)

    described_class.new.execute

    expect(CategoryActivityDailyRollup.count).to eq(0)
  end
end
