# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::TopicReceivedVote::V2 do
  fab!(:voter, :user)
  fab!(:author, :user)
  fab!(:category)
  fab!(:topic) { Fabricate(:topic, category:, user: author) }
  fab!(:vote) { Fabricate(:topic_voting_votes, user: voter, topic:) }

  before do
    SiteSetting.topic_voting_enabled = true
    SiteSetting.enable_discourse_workflows = true
    DiscourseTopicVoting::CategorySetting.create!(category:)
    Category.reset_voting_cache
    topic.update_vote_count
  end

  it "returns the voter as actor and the topic author as user", :aggregate_failures do
    output = described_class.new(vote).output

    expect(output[:actor][:username]).to eq(voter.username)
    expect(output[:user][:username]).to eq(author.username)
    expect(output).to match_node_output_schema(described_class)
  end
end
