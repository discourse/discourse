# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::TopicReceivedVote::V1 do
  fab!(:voter, :user)
  fab!(:category)
  fab!(:tag)
  fab!(:topic) { Fabricate(:topic, category: category, tags: [tag]) }
  fab!(:vote) { Fabricate(:topic_voting_votes, user: voter, topic: topic) }

  before do
    SiteSetting.topic_voting_enabled = true
    SiteSetting.enable_discourse_workflows = true
    DiscourseTopicVoting::CategorySetting.create!(category: category)
    Category.reset_voting_cache
    topic.update_vote_count
  end

  it "returns the correct identifier" do
    expect(described_class.identifier).to eq("trigger:topic_received_vote")
  end

  describe "#valid?" do
    it "returns true when a vote is present" do
      expect(described_class.new(vote)).to be_valid
    end

    it "returns false when the vote is nil" do
      expect(described_class.new(nil)).not_to be_valid
    end
  end

  describe "#output" do
    it "returns the topic, the voter and the vote", :aggregate_failures do
      output = described_class.new(vote).output

      expect(output[:topic][:id]).to eq(topic.id)
      expect(output[:user][:username]).to eq(voter.username)
      expect(output[:vote]).to include(id: vote.id, count: 1)
      expect(output).to match_node_output_schema(described_class)
    end
  end

  describe "#matches?" do
    it "matches every vote by default" do
      expect(described_class.new(vote).matches?(trigger_context({}))).to eq(true)
    end

    it "matches only votes on topics in the selected categories" do
      other_category = Fabricate(:category)

      expect(
        described_class.new(vote).matches?(trigger_context("category_ids" => [category.id])),
      ).to eq(true)
      expect(
        described_class.new(vote).matches?(trigger_context("category_ids" => [other_category.id])),
      ).to eq(false)
    end

    it "matches votes on topics in subcategories when subcategories are included" do
      parent_category = Fabricate(:category)
      category.update!(parent_category: parent_category)

      context = { "category_ids" => [parent_category.id] }

      expect(described_class.new(vote).matches?(trigger_context(context))).to eq(true)
      expect(
        described_class.new(vote).matches?(
          trigger_context(context.merge("include_subcategories" => false)),
        ),
      ).to eq(false)
    end

    it "matches only votes on topics carrying one of the selected tags" do
      expect(described_class.new(vote).matches?(trigger_context("tag_names" => [tag.name]))).to eq(
        true,
      )
      expect(described_class.new(vote).matches?(trigger_context("tag_names" => ["other"]))).to eq(
        false,
      )
    end
  end

  def trigger_context(parameters)
    DiscourseWorkflows::TriggerNodeContext.new({ "parameters" => parameters })
  end
end
