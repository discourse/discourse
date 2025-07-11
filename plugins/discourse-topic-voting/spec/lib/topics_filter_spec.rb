# frozen_string_literal: true

RSpec.describe TopicsFilter do
  describe "adding order:votes to DiscoursePluginRegistry.custom_filter_mappings" do
    fab!(:topic_high) { Fabricate(:topic_voting_vote_count, votes_count: 10).topic }
    fab!(:topic_med) { Fabricate(:topic_voting_vote_count, votes_count: 5).topic }
    fab!(:topic_low) { Fabricate(:topic_voting_vote_count, votes_count: 0).topic }
    fab!(:topic_nil) { Fabricate(:topic_voting_vote_count, votes_count: nil).topic }

    it "sorts votes in ascending order" do
      expect(
        TopicsFilter
          .new(guardian: Guardian.new)
          .filter_from_query_string("order:votes-asc")
          .pluck(:id),
      ).to eq([topic_low.id, topic_nil.id, topic_med.id, topic_high.id])
    end

    it "sorts votes in default descending order" do
      expect(
        TopicsFilter.new(guardian: Guardian.new).filter_from_query_string("order:votes").pluck(:id),
      ).to eq([topic_high.id, topic_med.id, topic_low.id, topic_nil.id])
    end
  end
end
