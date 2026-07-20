# frozen_string_literal: true

describe Report do
  fab!(:author, :user)

  def solved_topic_in(category)
    topic = Fabricate(:topic, category: category, user: author, created_at: 1.day.ago)
    answer = Fabricate(:post, topic: topic, user: author, created_at: 1.day.ago)
    Fabricate(:solved_topic, topic: topic, answer_post: answer, created_at: 1.day.ago)
    topic
  end

  def build(filters: {})
    Report.find("accepted_solutions", start_date: 2.days.ago, end_date: Time.current, filters:)
  end

  it "counts accepted solutions across all categories when no filter is given" do
    solved_topic_in(Fabricate(:category))
    solved_topic_in(Fabricate(:category))

    expect(build.total).to eq(2)
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
