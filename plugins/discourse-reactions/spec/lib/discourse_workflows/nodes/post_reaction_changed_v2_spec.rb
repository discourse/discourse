# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::PostReactionChanged::V2, discourse_workflows: true do
  fab!(:author, :user)
  fab!(:post) { Fabricate(:post, user: author) }
  fab!(:reactor, :user)

  before do
    SiteSetting.discourse_reactions_enabled = true
    SiteSetting.discourse_reactions_enabled_reactions = "laughing|hugs"
  end

  it "returns the reactor as actor and the post author as user", :aggregate_failures do
    DiscourseReactions::ReactionManager.new(reaction_value: "hugs", user: reactor, post:).toggle!
    trigger = described_class.new(post, reactor, nil)

    expect(trigger.output[:actor][:username]).to eq(reactor.username)
    expect(trigger.output[:user][:username]).to eq(author.username)
    expect(trigger.output).to match_node_output_schema(described_class)
  end
end
