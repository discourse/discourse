# frozen_string_literal: true

describe "accepted_solutions report" do # rubocop:disable RSpec/DescribeClass
  fab!(:author, :user)

  def solved_topic_in(category, created_at: 1.day.ago)
    topic = Fabricate(:topic, category: category, user: author, created_at:)
    answer = Fabricate(:post, topic: topic, user: author, created_at:)
    Fabricate(:solved_topic, topic: topic, answer_post: answer, created_at:)
    topic
  end

  def build(filters: {}, guardian: Discourse.system_user.guardian, facets: nil)
    Report.find(
      "accepted_solutions",
      start_date: 2.days.ago,
      end_date: Time.current,
      filters:,
      guardian:,
      facets:,
      include_related_items: true,
    )
  end

  it "restricts related items to admins while retaining moderator access to aggregates" do
    solved_topic_in(Fabricate(:category))
    moderator_guardian = Fabricate(:moderator).guardian
    report = build(guardian: moderator_guardian)

    expect(report.data.sum { |point| point[:y] }).to eq(1)
    expect(report.related_items).to be_nil
    expect(report.related_items_totals).to be_nil
  end

  it "counts accepted solutions across all categories when no filter is given" do
    solved_topic_in(Fabricate(:category))
    solved_topic_in(Fabricate(:category))

    expect(build.total).to eq(2)
  end

  it "counts accepted solutions outside the selected date range in the total" do
    category = Fabricate(:category)
    solved_topic_in(category)
    solved_topic_in(category, created_at: 3.days.ago)

    expect(build.total).to eq(2)
  end

  it "only calculates requested facets" do
    solved_topic_in(Fabricate(:category))

    report = build(facets: [:related_items])

    expect(report.total).to be_nil
    expect(report.prev30Days).to be_nil
    expect(report.related_items_totals).to eq(solved_topics: 1)
  end

  it "includes the solved topic, answer author, and category" do
    category = Fabricate(:category)
    topic = solved_topic_in(category)

    report = build
    item = report.related_items[:solved_topics].first

    expect(report.related_items_totals).to eq(solved_topics: 1)
    expect(item[:topic]).to eq(title: topic.title, url: topic.relative_url)
    expect(item.dig(:solved_by_users, 0, :username)).to eq(author.username)
    expect(item[:category]).to include(
      id: category.id,
      name: category.name,
      slug: category.slug,
      color: category.color,
    )
  end

  it "includes every accepted answer author when multiple solutions are enabled" do
    SiteSetting.solved_allow_multiple_solutions = true
    category = Fabricate(:category)
    topic = solved_topic_in(category)
    second_author = Fabricate(:user)
    second_answer = Fabricate(:post, topic:, user: second_author, created_at: 23.hours.ago)
    Fabricate(:topic_answer, solved_topic: topic.solved, post: second_answer, accepter: author)

    item = build.related_items[:solved_topics].first

    expect(item[:solved_by_users].map { |user| user[:username] }).to eq(
      [author.username, second_author.username],
    )
  end

  it "only includes solved topics from the selected date range" do
    category = Fabricate(:category)
    in_range_topic = solved_topic_in(category)
    solved_topic_in(category, created_at: 3.days.ago)

    report = build

    expect(report.related_items[:solved_topics].map { |item| item.dig(:topic, :title) }).to eq(
      [in_range_topic.title],
    )
  end

  it "skips related items when the report has no guardian" do
    solved_topic_in(Fabricate(:category))

    report = build(guardian: nil)

    expect(report.total).to eq(1)
    expect(report.related_items).to be_nil
    expect(report.related_items_totals).to be_nil
  end

  it "only includes solved topic details visible to the report guardian" do
    SiteSetting.suppress_secured_categories_from_admin = true
    private_topic = solved_topic_in(Fabricate(:private_category, group: Fabricate(:group)))
    visible_topic = solved_topic_in(Fabricate(:category))
    admin = Fabricate(:admin)

    expect(admin.guardian.can_see_topic?(private_topic)).to be(false)

    report = build(guardian: admin.guardian)

    expect(report.total).to eq(2)
    expect(report.related_items_totals).to eq(solved_topics: 1)
    expect(report.related_items[:solved_topics].map { |item| item.dig(:topic, :title) }).to eq(
      [visible_topic.title],
    )
  end

  it "excludes shared drafts from details when the report guardian cannot see them" do
    shared_drafts_category = Fabricate(:category)
    SiteSetting.suppress_secured_categories_from_admin = true
    SiteSetting.shared_drafts_category = shared_drafts_category.id
    SiteSetting.shared_drafts_allowed_groups = Fabricate(:group).id
    shared_draft_topic = solved_topic_in(shared_drafts_category)
    Fabricate(:shared_draft, topic: shared_draft_topic, category: Fabricate(:category))
    visible_topic = solved_topic_in(Fabricate(:category))
    admin = Fabricate(:admin)

    expect(admin.guardian.can_see_topic?(shared_draft_topic)).to be(false)

    report = build(guardian: admin.guardian)

    expect(report.total).to eq(2)
    expect(report.related_items_totals).to eq(solved_topics: 1)
    expect(report.related_items[:solved_topics].map { |item| item.dig(:topic, :title) }).to eq(
      [visible_topic.title],
    )
  end

  it "registers the category_ids filter even when no filter is given" do
    report = build

    filter = report.available_filters["category_ids"]
    expect(filter).to be_present
    expect(filter[:type]).to eq("category_list")
  end

  it "filters by category when the category_ids filter is provided" do
    target_category = Fabricate(:category)
    other_category = Fabricate(:category)
    solved_topic_in(target_category)
    solved_topic_in(other_category)

    report = build(filters: { category_ids: [target_category.id] })

    expect(report.total).to eq(1)
  end

  it "filters by the union of multiple categories" do
    first_category = Fabricate(:category)
    second_category = Fabricate(:category)
    other_category = Fabricate(:category)
    solved_topic_in(first_category)
    solved_topic_in(second_category)
    solved_topic_in(other_category)

    report = build(filters: { category_ids: [first_category.id, second_category.id] })

    expect(report.total).to eq(2)
  end

  it "accepts a comma-separated string of category ids" do
    first_category = Fabricate(:category)
    second_category = Fabricate(:category)
    other_category = Fabricate(:category)
    solved_topic_in(first_category)
    solved_topic_in(second_category)
    solved_topic_in(other_category)

    report = build(filters: { category_ids: "#{first_category.id},#{second_category.id}" })

    expect(report.total).to eq(2)
  end

  it "preserves the requested category order in the filter default" do
    first_category = Fabricate(:category)
    second_category = Fabricate(:category)

    report = build(filters: { category_ids: [second_category.id, first_category.id] })

    expect(report.available_filters["category_ids"][:default]).to eq(
      [second_category.id, first_category.id],
    )
  end

  it "strips category ids that don't correspond to an existing category" do
    target_category = Fabricate(:category)
    solved_topic_in(target_category)
    nonexistent_id = Category.unscoped.maximum(:id).to_i + 1

    report = build(filters: { category_ids: [target_category.id, nonexistent_id] })

    expect(report.total).to eq(1)
  end

  it "returns zero when a requested filter resolves to no valid ids" do
    solved_topic_in(Fabricate(:category))

    report = build(filters: { category_ids: "foo,bar" })

    expect(report.total).to eq(0)
  end
end
