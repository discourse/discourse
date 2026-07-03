# frozen_string_literal: true

RSpec.describe DiscourseSolved::AdminDashboardSupport do
  fab!(:support_category, :category)
  fab!(:admin)
  fab!(:author) { Fabricate(:user, trust_level: TrustLevel[1]) }
  fab!(:staff_user, :moderator)
  fab!(:member_user) { Fabricate(:user, trust_level: TrustLevel[2]) }

  before do
    SiteSetting.solved_enabled = true
    support_category.custom_fields[DiscourseSolved::ENABLE_ACCEPTED_ANSWERS_CUSTOM_FIELD] = "true"
    support_category.save!
  end

  def build(**opts)
    described_class.build(
      start_date: 30.days.ago.to_s,
      end_date: Time.zone.now.to_s,
      current_user: admin,
      **opts,
    )
  end

  def solved_topic(category: support_category, answerer: staff_user)
    topic = Fabricate(:topic, category: category, user: author)
    Fabricate(:post, topic: topic, user: author)
    answer = Fabricate(:post, topic: topic, user: answerer)
    Fabricate(:solved_topic, topic: topic, answer_post: answer)
    topic
  end

  def answered_topic(category: support_category, answerer: member_user)
    topic = Fabricate(:topic, category: category, user: author)
    Fabricate(:post, topic: topic, user: author)
    Fabricate(:post, topic: topic, user: answerer)
    topic
  end

  def unanswered_topic(category: support_category)
    topic = Fabricate(:topic, category: category, user: author)
    Fabricate(:post, topic: topic, user: author)
    topic
  end

  describe ".available?" do
    it "is true when a support category exists" do
      expect(described_class.available?).to eq(true)
    end

    it "is false when the plugin is disabled" do
      SiteSetting.solved_enabled = false
      expect(described_class.available?).to eq(false)
    end

    it "is false when no category enables accepted answers" do
      support_category.custom_fields[
        DiscourseSolved::ENABLE_ACCEPTED_ANSWERS_CUSTOM_FIELD
      ] = "false"
      support_category.save!
      Discourse.cache.delete(DiscourseSolved::AdminDashboardSupport::AVAILABILITY_CACHE_KEY)

      expect(described_class.available?).to eq(false)
    end
  end

  describe "topic outcomes" do
    it "counts resolved, in progress, and unanswered as mutually exclusive states" do
      solved_topic
      answered_topic
      unanswered_topic

      expect(build[:topic_outcomes]).to eq(resolved: 1, in_progress: 1, unanswered: 1)
    end

    it "serves cached data for the same scope and window within the TTL" do
      solved_topic

      expect(build[:topic_outcomes]).to eq(resolved: 1, in_progress: 0, unanswered: 0)

      solved_topic

      expect(build[:topic_outcomes]).to eq(resolved: 1, in_progress: 0, unanswered: 0)
    end
  end

  describe "resolution rate KPI" do
    it "is the share of period topics that were solved" do
      solved_topic
      answered_topic
      unanswered_topic

      expect(build[:kpis][:resolution_rate][:value]).to eq(33.3)
    end

    it "carries the selected category into the report drill-down query" do
      solved_topic

      query = build(category_id: support_category.id)[:kpis][:resolution_rate][:report_query]

      expect(query[:filters]).to eq(category: support_category.id)
    end

    it "omits the category filter when viewing all categories" do
      solved_topic

      expect(build[:kpis][:resolution_rate][:report_query]).not_to have_key(:filters)
    end
  end

  describe "staff involvement KPI" do
    it "is the share of topics whose first reply came from staff" do
      solved_topic(answerer: staff_user)
      answered_topic(answerer: member_user)

      expect(build[:kpis][:staff_involvement][:value]).to eq(50.0)
    end
  end

  describe "who's answering" do
    it "groups repliers by staff and trust level, sharing out the totals" do
      solved_topic(answerer: staff_user)
      answered_topic(answerer: member_user)

      rows = build[:whos_answering][:rows]

      expect(build[:whos_answering][:total]).to eq(2)
      expect(rows.find { |row| row[:type] == "staff" }[:count]).to eq(1)
      expect(rows.find { |row| row[:type] == "member" }[:count]).to eq(1)
    end

    it "does not count the topic author replying to their own topic" do
      topic = Fabricate(:topic, category: support_category, user: author)
      Fabricate(:post, topic: topic, user: author)
      Fabricate(:post, topic: topic, user: author)

      expect(build[:whos_answering][:total]).to eq(0)
    end
  end

  describe "response time distribution" do
    it "buckets first-reply times and reports the average" do
      answered_topic

      distribution = build[:response_time_distribution]

      expect(distribution[:buckets].sum { |bucket| bucket[:count] }).to eq(1)
      expect(build[:kpis][:avg_first_reply][:value]).not_to be_nil
    end
  end

  describe "category scoping" do
    fab!(:second_support_category, :category)

    before do
      second_support_category.custom_fields[
        DiscourseSolved::ENABLE_ACCEPTED_ANSWERS_CUSTOM_FIELD
      ] = "true"
      second_support_category.save!
    end

    it "limits metrics to a single category when one is selected" do
      solved_topic(category: support_category)
      solved_topic(category: second_support_category)

      expect(build[:topic_outcomes][:resolved]).to eq(2)
      expect(build(category_id: support_category.id)[:topic_outcomes][:resolved]).to eq(1)
    end

    it "lists both support categories as filter options" do
      expect(build[:category_options].map { |option| option[:id] }).to contain_exactly(
        support_category.id,
        second_support_category.id,
      )
    end
  end

  describe "when solved is enabled on all topics" do
    fab!(:plain_category, :category)

    before { SiteSetting.allow_solved_on_all_topics = true }

    it "offers every visible category as a filter option, not just flagged ones" do
      ids = build[:category_options].map { |option| option[:id] }

      expect(ids).to include(support_category.id, plain_category.id)
    end
  end

  describe "guardian scoping" do
    fab!(:group)
    fab!(:restricted_category) { Fabricate(:private_category, group: group) }
    fab!(:outsider, :moderator)

    before do
      restricted_category.custom_fields[
        DiscourseSolved::ENABLE_ACCEPTED_ANSWERS_CUSTOM_FIELD
      ] = "true"
      restricted_category.save!
      solved_topic(category: restricted_category)
    end

    it "excludes categories the viewer cannot see" do
      as_admin = build[:topic_outcomes][:resolved]
      as_outsider =
        described_class.build(
          start_date: 30.days.ago.to_s,
          end_date: Time.zone.now.to_s,
          current_user: outsider,
        )[
          :topic_outcomes
        ][
          :resolved
        ]

      expect(as_admin).to eq(1)
      expect(as_outsider).to eq(0)
    end
  end
end
