# frozen_string_literal: true

RSpec.describe TopicsFilter do
  before { SiteSetting.topic_voting_enabled = true }

  describe "topics filter option metadata" do
    it "adds topic voting range filters and order helpers" do
      options = TopicsFilter.option_info(Guardian.new)

      min_option = options.find { |option| option[:name] == "votes-min:" }
      max_option = options.find { |option| option[:name] == "votes-max:" }
      order_option = options.find { |option| option[:name] == "order:votes" }
      order_asc_option = options.find { |option| option[:name] == "order:votes-asc" }

      expect(min_option).to include(
        name: "votes-min:",
        description: I18n.t("topic_voting.filter.description.topic_votes_min"),
        type: "number",
      )

      expect(max_option).to include(
        name: "votes-max:",
        description: I18n.t("topic_voting.filter.description.topic_votes_max"),
        type: "number",
      )

      expect(order_option).to include(
        name: "order:votes",
        description: I18n.t("topic_voting.filter.description.order_topic_votes"),
      )

      expect(order_asc_option).to include(
        name: "order:votes-asc",
        description: I18n.t("topic_voting.filter.description.order_topic_votes_asc"),
      )
    end
  end

  describe "topic votes filtering" do
    fab!(:voting_category, :category)
    fab!(:non_voting_category, :category)
    let!(:_category_setting) do
      DiscourseTopicVoting::CategorySetting.create!(category: voting_category)
    end

    fab!(:topic_high) do
      topic = Fabricate(:topic, category: voting_category)
      Fabricate(:topic_voting_vote_count, topic:, votes_count: 10)
      topic
    end

    fab!(:topic_med) do
      topic = Fabricate(:topic, category: voting_category)
      Fabricate(:topic_voting_vote_count, topic:, votes_count: 5)
      topic
    end

    fab!(:topic_low) do
      topic = Fabricate(:topic, category: voting_category)
      Fabricate(:topic_voting_vote_count, topic:, votes_count: 0)
      topic
    end

    fab!(:topic_nil) do
      topic = Fabricate(:topic, category: voting_category)
      Fabricate(:topic_voting_vote_count, topic:, votes_count: nil)
      topic
    end

    fab!(:topic_without_count) { Fabricate(:topic, category: voting_category) }

    fab!(:non_voting_topic) do
      topic = Fabricate(:topic, category: non_voting_category)
      Fabricate(:topic_voting_vote_count, topic:, votes_count: 20)
      topic
    end

    let(:filter) { TopicsFilter.new(guardian: Guardian.new) }

    it "filters by minimum vote count" do
      expect(filter.filter_from_query_string("votes-min:6").pluck(:id)).to eq([topic_high.id])
    end

    it "filters by maximum vote count including topics without vote counts" do
      expect(filter.filter_from_query_string("votes-max:0").pluck(:id)).to match_array(
        [topic_low.id, topic_nil.id, topic_without_count.id],
      )
    end

    it "sorts by topic votes descending by default" do
      ids = filter.filter_from_query_string("order:votes").pluck(:id)

      expect(ids.first(2)).to eq([topic_high.id, topic_med.id])
      expect(ids.last(3)).to match_array([topic_low.id, topic_nil.id, topic_without_count.id])
    end

    it "sorts by topic votes ascending when requested" do
      ids = filter.filter_from_query_string("order:votes-asc").pluck(:id)

      expect(ids.last(2)).to eq([topic_med.id, topic_high.id])
      expect(ids.first(3)).to match_array([topic_low.id, topic_nil.id, topic_without_count.id])
    end
  end
end
