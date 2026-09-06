# frozen_string_literal: true

RSpec.describe Jobs::RebuildCategoryActivityDailyRollups do
  fab!(:category)

  before { freeze_time(Time.zone.local(2026, 4, 28, 12)) }

  it "rolls up the whole history" do
    Fabricate(:topic, category: category, created_at: 200.days.ago)
    Fabricate(:topic, category: category, created_at: 1.day.ago)

    described_class.new.execute

    expect(CategoryActivityDailyRollup.pluck(:date)).to contain_exactly(
      200.days.ago.to_date,
      1.day.ago.to_date,
    )
  end

  it "reattributes activity after an old topic is moved to another category" do
    other_category = Fabricate(:category)
    topic = Fabricate(:topic, category: category, created_at: 200.days.ago)
    described_class.new.execute

    topic.update_columns(category_id: other_category.id)
    described_class.new.execute

    row = CategoryActivityDailyRollup.find_by(date: 200.days.ago.to_date)
    expect(row.category_id).to eq(other_category.id)
  end

  it "drops activity after an old topic is deleted" do
    topic = Fabricate(:topic, category: category, created_at: 200.days.ago)
    described_class.new.execute

    topic.update_columns(deleted_at: Time.zone.now)
    described_class.new.execute

    expect(CategoryActivityDailyRollup.exists?(date: 200.days.ago.to_date)).to eq(false)
  end

  it "fills a gap left by a period without rollups" do
    Fabricate(:topic, category: category, created_at: 60.days.ago)
    Fabricate(:category_activity_daily_rollup, category: category, date: 100.days.ago)

    described_class.new.execute

    expect(CategoryActivityDailyRollup.exists?(date: 60.days.ago.to_date)).to eq(true)
  end

  it "does nothing on a site whose only topics are excluded from the rollup" do
    Fabricate(:topic, category: category, created_at: 200.days.ago, deleted_at: Time.zone.now)
    Fabricate(:private_message_topic, created_at: 200.days.ago)

    described_class.new.execute

    expect(CategoryActivityDailyRollup.count).to eq(0)
  end
end
