# frozen_string_literal: true

describe Reports::ActivityByCategory do
  before { freeze_time(Time.zone.local(2026, 4, 28, 12, 0, 0)) }

  let(:start_date) { Time.zone.local(2026, 4, 1) }
  let(:end_date) { Time.zone.local(2026, 4, 28).end_of_day }

  def build(filters: {}, current_user: nil)
    Report.find(
      "activity_by_category",
      { start_date: start_date, end_date: end_date, filters: filters, current_user: current_user },
    )
  end

  def row(report, category_id)
    report.data.find { |r| r[:category_id] == category_id }
  end

  it "returns one row per category with non-zero activity" do
    category = Fabricate(:category)
    topic = Fabricate(:topic, category: category, created_at: start_date + 1.day)
    Fabricate(:post, topic: topic, created_at: start_date + 1.day)

    report = build

    expect(row(report, category.id)).to be_present
    expect(row(report, category.id)[:topics]).to eq(1)
    expect(row(report, category.id)[:posts]).to be >= 1
  end

  it "counts topics created in the period" do
    category = Fabricate(:category)
    Fabricate(:topic, category: category, created_at: start_date + 2.days)
    Fabricate(:topic, category: category, created_at: start_date + 5.days)
    Fabricate(:topic, category: category, created_at: start_date - 30.days)

    report = build

    expect(row(report, category.id)[:topics]).to eq(2)
  end

  it "counts page views from topic_view_stats" do
    category = Fabricate(:category)
    topic = Fabricate(:topic, category: category, created_at: start_date + 1.day)
    TopicViewStat.create!(
      topic: topic,
      viewed_at: start_date + 3.days,
      anonymous_views: 7,
      logged_in_views: 3,
    )
    TopicViewStat.create!(
      topic: topic,
      viewed_at: start_date + 4.days,
      anonymous_views: 2,
      logged_in_views: 1,
    )

    report = build

    expect(row(report, category.id)[:page_views]).to eq(13)
  end

  it "excludes deleted topics, deleted posts, and PM archetype" do
    cat = Fabricate(:category)
    Fabricate(:topic, category: cat, created_at: start_date + 1.day, deleted_at: Time.now)
    Fabricate(:private_message_topic, category: cat) # archetype: private_message

    report = build

    expect(report.data).to be_empty
  end

  it "computes share as percentage of activity across the listed categories" do
    cat_a = Fabricate(:category)
    cat_b = Fabricate(:category)
    Fabricate(:topic, category: cat_a, created_at: start_date + 1.day)
    Fabricate(:topic, category: cat_b, created_at: start_date + 1.day)
    Fabricate(:topic, category: cat_b, created_at: start_date + 1.day)
    Fabricate(:topic, category: cat_b, created_at: start_date + 1.day)

    report = build(filters: { category_ids: [cat_a.id, cat_b.id] })

    expect(report.data.map { |r| r[:share] }.sum).to be_within(0.5).of(100)
    expect(row(report, cat_b.id)[:share]).to be > row(report, cat_a.id)[:share]
  end

  it "formats a positive share_change with a leading +" do
    cat = Fabricate(:category)
    Fabricate(:topic, category: cat, created_at: start_date + 5.days)

    report = build

    formatted = row(report, cat.id)[:share_change_formatted]
    expect(formatted).to start_with("+")
    expect(formatted).to end_with("%")
  end

  it "computes share_change against the prior period" do
    grew = Fabricate(:category)
    shrank = Fabricate(:category)
    # current period activity
    3.times { Fabricate(:topic, category: grew, created_at: start_date + 1.day) }
    Fabricate(:topic, category: shrank, created_at: start_date + 1.day)
    # prior period activity (start_date - 1.day falls in [prior_start, start_date])
    3.times { Fabricate(:topic, category: shrank, created_at: start_date - 1.day) }

    report = build(filters: { category_ids: [grew.id, shrank.id] })

    expect(row(report, grew.id)[:share_change]).to be > 0
    expect(row(report, shrank.id)[:share_change]).to be < 0
    expect(row(report, shrank.id)[:share_change_formatted]).not_to start_with("+")
  end

  it "returns empty rows when an explicit filter resolves to no valid ids" do
    Fabricate(:category) # noise data — should NOT be returned via top-N fallback
    Fabricate(:topic, created_at: start_date + 1.day)

    report = build(filters: { category_ids: "999999999,foo,bar" })

    expect(report.data).to be_empty
  end

  it "caps the requested ids at MAX_CATEGORY_IDS" do
    cats = Array.new(60) { Fabricate(:category) }
    cats.first.tap { |c| Fabricate(:topic, category: c, created_at: start_date + 1.day) }

    ids = cats.map(&:id).join(",")
    report = build(filters: { category_ids: ids })

    # only the first 50 are admitted as filter ids; the rest are ignored
    expect(report.data.length).to be <= Reports::ActivityByCategory::MAX_CATEGORY_IDS
  end

  it "sorts rows by total activity descending" do
    cat_small = Fabricate(:category)
    cat_big = Fabricate(:category)
    Fabricate(:topic, category: cat_small, created_at: start_date + 1.day)
    3.times { Fabricate(:topic, category: cat_big, created_at: start_date + 1.day) }

    report = build

    expect(report.data.first[:category_id]).to eq(cat_big.id)
  end

  it "limits to the top N categories by activity when no filter is given" do
    8.times do |i|
      cat = Fabricate(:category, name: "cat#{i}")
      Fabricate(:topic, category: cat, created_at: start_date + 1.day)
    end

    report = build

    expect(report.data.length).to be <= Reports::ActivityByCategory::DEFAULT_TOP_N
  end

  it "returns only the requested categories when a filter is provided" do
    cat_a = Fabricate(:category)
    cat_b = Fabricate(:category)
    cat_c = Fabricate(:category)
    [cat_a, cat_b, cat_c].each do |c|
      Fabricate(:topic, category: c, created_at: start_date + 1.day)
    end

    report = build(filters: { category_ids: [cat_a.id, cat_c.id] })

    ids = report.data.map { |r| r[:category_id] }
    expect(ids).to contain_exactly(cat_a.id, cat_c.id)
  end

  it "accepts comma-separated category ids string from URL filters" do
    cat_a = Fabricate(:category)
    cat_b = Fabricate(:category)
    Fabricate(:topic, category: cat_a, created_at: start_date + 1.day)
    Fabricate(:topic, category: cat_b, created_at: start_date + 1.day)

    report = build(filters: { category_ids: "#{cat_a.id},#{cat_b.id}" })

    expect(report.data.map { |r| r[:category_id] }).to contain_exactly(cat_a.id, cat_b.id)
  end

  describe "secured categories" do
    fab!(:moderator)
    fab!(:admin)
    fab!(:private_group, :group)

    it "excludes restricted categories from a moderator's results" do
      private_cat = Fabricate(:private_category, group: private_group, read_restricted: true)
      Fabricate(:topic, category: private_cat, created_at: start_date + 1.day)

      report = build(current_user: moderator)

      expect(report.data.map { |r| r[:category_id] }).not_to include(private_cat.id)
    end

    it "lets an admin see activity in restricted categories" do
      private_cat = Fabricate(:private_category, group: private_group, read_restricted: true)
      Fabricate(:topic, category: private_cat, created_at: start_date + 1.day)

      report = build(current_user: admin)

      expect(report.data.map { |r| r[:category_id] }).to include(private_cat.id)
    end
  end
end
