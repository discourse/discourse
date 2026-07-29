# frozen_string_literal: true

describe "accepted_solutions report" do # rubocop:disable RSpec/DescribeClass
  fab!(:author, :user)

  it "counts accepted solutions across all categories when no filter is given" do
    topic = Fabricate(:topic, category: Fabricate(:category), user: author, created_at: 1.day.ago)
    answer = Fabricate(:post, topic:, user: author, created_at: 1.day.ago)
    Fabricate(:solved_topic, topic:, answer_post: answer, created_at: 1.day.ago)

    topic = Fabricate(:topic, category: Fabricate(:category), user: author, created_at: 1.day.ago)
    answer = Fabricate(:post, topic:, user: author, created_at: 1.day.ago)
    Fabricate(:solved_topic, topic:, answer_post: answer, created_at: 1.day.ago)

    report =
      Report.find("accepted_solutions", start_date: 2.days.ago, end_date: Time.current, filters: {})

    expect(report.total).to eq(2)
  end

  it "filters by category when the category_ids filter is provided" do
    target_category = Fabricate(:category)
    other_category = Fabricate(:category)

    topic = Fabricate(:topic, category: target_category, user: author, created_at: 1.day.ago)
    answer = Fabricate(:post, topic:, user: author, created_at: 1.day.ago)
    Fabricate(:solved_topic, topic:, answer_post: answer, created_at: 1.day.ago)

    topic = Fabricate(:topic, category: other_category, user: author, created_at: 1.day.ago)
    answer = Fabricate(:post, topic:, user: author, created_at: 1.day.ago)
    Fabricate(:solved_topic, topic:, answer_post: answer, created_at: 1.day.ago)

    report =
      Report.find(
        "accepted_solutions",
        start_date: 2.days.ago,
        end_date: Time.current,
        filters: {
          category_ids: [target_category.id],
        },
      )

    expect(report.total).to eq(1)
  end

  it "filters by the union of multiple categories" do
    first_category = Fabricate(:category)
    second_category = Fabricate(:category)
    other_category = Fabricate(:category)

    [first_category, second_category, other_category].each do |category|
      topic = Fabricate(:topic, category:, user: author, created_at: 1.day.ago)
      answer = Fabricate(:post, topic:, user: author, created_at: 1.day.ago)
      Fabricate(:solved_topic, topic:, answer_post: answer, created_at: 1.day.ago)
    end

    report =
      Report.find(
        "accepted_solutions",
        start_date: 2.days.ago,
        end_date: Time.current,
        filters: {
          category_ids: [first_category.id, second_category.id],
        },
      )

    expect(report.total).to eq(2)
  end

  it "accepts a comma-separated string of category ids" do
    first_category = Fabricate(:category)
    second_category = Fabricate(:category)
    other_category = Fabricate(:category)

    [first_category, second_category, other_category].each do |category|
      topic = Fabricate(:topic, category:, user: author, created_at: 1.day.ago)
      answer = Fabricate(:post, topic:, user: author, created_at: 1.day.ago)
      Fabricate(:solved_topic, topic:, answer_post: answer, created_at: 1.day.ago)
    end

    report =
      Report.find(
        "accepted_solutions",
        start_date: 2.days.ago,
        end_date: Time.current,
        filters: {
          category_ids: "#{first_category.id},#{second_category.id}",
        },
      )

    expect(report.total).to eq(2)
  end

  it "strips category ids that don't correspond to an existing category" do
    target_category = Fabricate(:category)
    topic = Fabricate(:topic, category: target_category, user: author, created_at: 1.day.ago)
    answer = Fabricate(:post, topic:, user: author, created_at: 1.day.ago)
    Fabricate(:solved_topic, topic:, answer_post: answer, created_at: 1.day.ago)
    nonexistent_id = Category.unscoped.maximum(:id).to_i + 1

    report =
      Report.find(
        "accepted_solutions",
        start_date: 2.days.ago,
        end_date: Time.current,
        filters: {
          category_ids: [target_category.id, nonexistent_id],
        },
      )

    expect(report.total).to eq(1)
  end

  it "returns zero when a requested filter resolves to no valid ids" do
    topic = Fabricate(:topic, category: Fabricate(:category), user: author, created_at: 1.day.ago)
    answer = Fabricate(:post, topic:, user: author, created_at: 1.day.ago)
    Fabricate(:solved_topic, topic:, answer_post: answer, created_at: 1.day.ago)

    report =
      Report.find(
        "accepted_solutions",
        start_date: 2.days.ago,
        end_date: Time.current,
        filters: {
          category_ids: "foo,bar",
        },
      )

    expect(report.total).to eq(0)
  end
end
