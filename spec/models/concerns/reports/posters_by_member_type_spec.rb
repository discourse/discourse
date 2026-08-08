# frozen_string_literal: true

describe Reports::PostersByMemberType do
  before { freeze_time(Time.zone.local(2026, 4, 28, 12, 0, 0)) }

  let(:start_date) { Time.zone.local(2026, 4, 1) }
  let(:end_date) { Time.zone.local(2026, 4, 28).end_of_day }

  def build(filters: {}, current_user: nil)
    Report.find(
      "posters_by_member_type",
      { start_date: start_date, end_date: end_date, filters: filters, current_user: current_user },
    )
  end

  def row(report, type)
    report.data.find { |r| r[:type] == type }
  end

  it "returns three rows in fixed order: new_members, returning, staff" do
    report = build

    types = report.data.map { |r| r[:type] }
    expect(types).to eq(%i[new_members returning staff])
  end

  it "counts staff posts in the staff bucket regardless of join date" do
    admin = Fabricate(:admin, created_at: start_date + 1.day)
    moderator = Fabricate(:moderator, created_at: 6.months.ago)
    Fabricate(:post, user: admin, created_at: start_date + 5.days)
    Fabricate(:post, user: moderator, created_at: start_date + 6.days)

    report = build

    expect(row(report, :staff)[:count]).to eq(2)
    expect(row(report, :new_members)[:count]).to eq(0)
    expect(row(report, :returning)[:count]).to eq(0)
  end

  it "bucketing new members by users who signed up within the period" do
    new_user = Fabricate(:user, created_at: start_date + 2.days)
    Fabricate(:post, user: new_user, created_at: start_date + 3.days)

    report = build

    expect(row(report, :new_members)[:count]).to eq(1)
  end

  it "bucketing returning members by users who signed up before the period" do
    returning_user = Fabricate(:user, created_at: start_date - 30.days)
    Fabricate(:post, user: returning_user, created_at: start_date + 1.day)

    report = build

    expect(row(report, :returning)[:count]).to eq(1)
  end

  it "computes share as a percentage of the period's posts" do
    new_user = Fabricate(:user, created_at: start_date + 1.day)
    returning_user = Fabricate(:user, created_at: start_date - 30.days)
    Fabricate(:post, user: new_user, created_at: start_date + 2.days)
    Fabricate(:post, user: returning_user, created_at: start_date + 3.days)
    Fabricate(:post, user: returning_user, created_at: start_date + 4.days)

    report = build

    expect(row(report, :new_members)[:share]).to eq(33.33)
    expect(row(report, :returning)[:share]).to eq(66.67)
    expect(report.data.sum { |r| r[:share] }).to be_within(0.5).of(100)
  end

  it "excludes deleted posts" do
    user = Fabricate(:user, created_at: start_date - 30.days)
    Fabricate(:post, user: user, created_at: start_date + 1.day, deleted_at: Time.now)

    report = build

    expect(row(report, :returning)[:count]).to eq(0)
  end

  it "excludes posts in deleted topics" do
    user = Fabricate(:user, created_at: start_date - 30.days)
    topic = Fabricate(:topic, deleted_at: Time.now)
    Fabricate(:post, user: user, topic: topic, created_at: start_date + 1.day)

    report = build

    expect(row(report, :returning)[:count]).to eq(0)
  end

  it "excludes posts in private messages" do
    user = Fabricate(:user, created_at: start_date - 30.days)
    pm = Fabricate(:private_message_topic)
    Fabricate(:post, user: user, topic: pm, created_at: start_date + 1.day)

    report = build

    expect(row(report, :returning)[:count]).to eq(0)
  end

  it "excludes posts from system users (id <= 0)" do
    Fabricate(:post, user: Discourse.system_user, created_at: start_date + 1.day)

    report = build

    expect(report.data.sum { |r| r[:count] }).to eq(0)
  end

  it "excludes non-regular post types" do
    user = Fabricate(:user, created_at: start_date - 30.days)
    Fabricate(
      :post,
      user: user,
      created_at: start_date + 1.day,
      post_type: Post.types[:moderator_action],
    )

    report = build

    expect(row(report, :returning)[:count]).to eq(0)
  end

  it "filters by category when the category_ids filter is provided" do
    user = Fabricate(:user, created_at: start_date - 30.days)
    target_category = Fabricate(:category)
    other_category = Fabricate(:category)
    target_topic = Fabricate(:topic, category: target_category)
    other_topic = Fabricate(:topic, category: other_category)
    Fabricate(:post, user: user, topic: target_topic, created_at: start_date + 1.day)
    Fabricate(:post, user: user, topic: other_topic, created_at: start_date + 1.day)

    report = build(filters: { category_ids: [target_category.id] })

    expect(row(report, :returning)[:count]).to eq(1)
  end

  it "filters by the union of multiple categories" do
    user = Fabricate(:user, created_at: start_date - 30.days)
    first_category = Fabricate(:category)
    second_category = Fabricate(:category)
    other_category = Fabricate(:category)
    first_topic = Fabricate(:topic, category: first_category)
    second_topic = Fabricate(:topic, category: second_category)
    other_topic = Fabricate(:topic, category: other_category)
    Fabricate(:post, user: user, topic: first_topic, created_at: start_date + 1.day)
    Fabricate(:post, user: user, topic: second_topic, created_at: start_date + 1.day)
    Fabricate(:post, user: user, topic: other_topic, created_at: start_date + 1.day)

    report = build(filters: { category_ids: [first_category.id, second_category.id] })

    expect(row(report, :returning)[:count]).to eq(2)
  end

  it "accepts a comma-separated string of category ids" do
    user = Fabricate(:user, created_at: start_date - 30.days)
    target_category = Fabricate(:category)
    other_category = Fabricate(:category)
    target_topic = Fabricate(:topic, category: target_category)
    other_topic = Fabricate(:topic, category: other_category)
    Fabricate(:post, user: user, topic: target_topic, created_at: start_date + 1.day)
    Fabricate(:post, user: user, topic: other_topic, created_at: start_date + 1.day)

    report = build(filters: { category_ids: target_category.id.to_s })

    expect(row(report, :returning)[:count]).to eq(1)
  end

  it "returns zero counts when a requested filter resolves to no valid ids" do
    user = Fabricate(:user, created_at: start_date - 30.days)
    topic = Fabricate(:topic, category: Fabricate(:category))
    Fabricate(:post, user: user, topic: topic, created_at: start_date + 1.day)

    report = build(filters: { category_ids: "foo,bar" })

    expect(report.total).to eq(0)
    expect(report.data.sum { |r| r[:count] }).to eq(0)
  end

  it "strips category ids that don't correspond to an existing category" do
    nonexistent_id = Category.unscoped.maximum(:id).to_i + 1

    report = build(filters: { category_ids: [nonexistent_id] })

    expect(report.available_filters["category_ids"][:default]).to eq([])
  end

  it "keeps only the existing ids when the filter mixes real and nonexistent categories" do
    user = Fabricate(:user, created_at: start_date - 30.days)
    target_category = Fabricate(:category)
    target_topic = Fabricate(:topic, category: target_category)
    Fabricate(:post, user: user, topic: target_topic, created_at: start_date + 1.day)
    nonexistent_id = Category.unscoped.maximum(:id).to_i + 1

    report = build(filters: { category_ids: [target_category.id, nonexistent_id] })

    expect(report.available_filters["category_ids"][:default]).to eq([target_category.id])
    expect(row(report, :returning)[:count]).to eq(1)
  end

  it "preserves the requested order of the category ids" do
    first = Fabricate(:category)
    second = Fabricate(:category)
    third = Fabricate(:category)

    report = build(filters: { category_ids: [third.id, first.id, second.id] })

    expect(report.available_filters["category_ids"][:default]).to eq(
      [third.id, first.id, second.id],
    )
  end

  it "caps the requested ids at MAX_CATEGORY_IDS" do
    cats = Array.new(60) { Fabricate(:category) }

    report = build(filters: { category_ids: cats.map(&:id).join(",") })

    expect(report.available_filters["category_ids"][:default].length).to eq(
      Reports::PostersByMemberType::MAX_CATEGORY_IDS,
    )
  end

  it "renders a unicode category name without errors" do
    user = Fabricate(:user, created_at: start_date - 30.days)
    cat = Fabricate(:category, name: "字テスト")
    topic = Fabricate(:topic, category: cat)
    Fabricate(:post, user: user, topic: topic, created_at: start_date + 1.day)

    expect { build(filters: { category_ids: [cat.id] }) }.not_to raise_error
  end

  describe "secured categories" do
    fab!(:moderator)
    fab!(:admin)
    fab!(:private_group, :group)

    it "excludes posts in restricted categories from a moderator's unfiltered total" do
      private_category = Fabricate(:private_category, group: private_group, read_restricted: true)
      poster = Fabricate(:user, created_at: start_date - 30.days)
      topic = Fabricate(:topic, category: private_category)
      Fabricate(:post, user: poster, topic: topic, created_at: start_date + 1.day)

      report = build(current_user: moderator)

      expect(report.data.sum { |r| r[:count] }).to eq(0)
    end

    it "returns zero when a moderator filters by a category they cannot access" do
      private_category = Fabricate(:private_category, group: private_group, read_restricted: true)
      poster = Fabricate(:user, created_at: start_date - 30.days)
      topic = Fabricate(:topic, category: private_category)
      Fabricate(:post, user: poster, topic: topic, created_at: start_date + 1.day)

      report = build(filters: { category_ids: [private_category.id] }, current_user: moderator)

      expect(row(report, :returning)[:count]).to eq(0)
    end

    it "lets an admin see posts in restricted categories" do
      private_category = Fabricate(:private_category, group: private_group, read_restricted: true)
      poster = Fabricate(:user, created_at: start_date - 30.days)
      topic = Fabricate(:topic, category: private_category)
      Fabricate(:post, user: poster, topic: topic, created_at: start_date + 1.day)

      report = build(filters: { category_ids: [private_category.id] }, current_user: admin)

      expect(row(report, :returning)[:count]).to eq(1)
    end
  end
end
