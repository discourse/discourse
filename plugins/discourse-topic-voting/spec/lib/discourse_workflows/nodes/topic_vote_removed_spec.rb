# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::TopicVoteRemoved::V1 do
  fab!(:voter, :user)
  fab!(:author, :user)
  fab!(:category)
  fab!(:topic) { Fabricate(:topic, category:, user: author) }

  before do
    SiteSetting.topic_voting_enabled = true
    SiteSetting.enable_discourse_workflows = true
    DiscourseTopicVoting::CategorySetting.create!(category:)
    Category.reset_voting_cache
    Fabricate(:topic_voting_votes, user: voter, topic:)
    topic.update_vote_count
  end

  it "reports the removed vote with the voter as actor", :aggregate_failures do
    event =
      DiscourseEvent.track(:topic_voting_vote_destroyed) do
        DiscourseTopicVoting::Votes::Remove.call(
          params: {
            topic_id: topic.id,
          },
          guardian: voter.guardian,
        )
      end
    trigger = described_class.new(*event[:params])

    expect(trigger).to be_valid
    expect(trigger.output).to include(
      topic: include(id: topic.id),
      user: include(id: author.id),
      actor: include(id: voter.id),
      vote: include(count: 0),
    )
    expect(trigger.output).to match_node_output_schema(described_class)
    expect(described_class.description[:event]).to eq(:topic_voting_vote_destroyed)
  end
end
