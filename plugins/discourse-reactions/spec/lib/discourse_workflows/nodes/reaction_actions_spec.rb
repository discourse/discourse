# frozen_string_literal: true

RSpec.shared_context "with a post to react to" do
  fab!(:author, :user)
  fab!(:post) { Fabricate(:post, user: author) }
  fab!(:actor, :user)

  before do
    SiteSetting.discourse_reactions_enabled = true
    SiteSetting.discourse_reactions_enabled_reactions = "laughing|hugs"
  end

  def run_node(reaction: ":laughing:", **rest)
    execute_node(
      configuration: {
        "post_id" => post.id.to_s,
        "reaction" => reaction,
        "actor_username" => actor.username,
        **rest.stringify_keys,
      },
    )
  end

  def react(reaction)
    DiscourseReactions::PostReaction::Toggle.call(
      params: {
        post_id: post.id,
        reaction:,
      },
      guardian: actor.guardian,
    )
  end

  def current_reaction
    DiscourseReactions::ReactionManager.reaction_value_for(user: actor, post:)
  end
end

RSpec.describe DiscourseWorkflows::Nodes::AddReaction::V1 do
  include_context "with a post to react to"

  it "reacts as the actor", :aggregate_failures do
    result = nil
    events = DiscourseEvent.track_events(:post_reaction_toggled) { result = run_node }

    expect(result).to include(
      "post" => include("id" => post.id),
      "actor" => include("id" => actor.id),
      "reaction" => "laughing",
      "previous_reaction" => nil,
      "changed" => true,
    )
    expect(result).to match_node_output_schema(described_class)
    expect(events.sole[:params]).to eq([post, actor, nil])
  end

  it "keeps another reaction by default" do
    react("hugs")

    expect(run_node).to include("changed" => false, "reaction" => "hugs")
  end

  it "replaces another reaction when asked", :aggregate_failures do
    react("hugs")

    expect(run_node(if_exists: "replace")).to include(
      "changed" => true,
      "reaction" => "laughing",
      "previous_reaction" => "hugs",
    )
  end

  it "reports nothing changed when the actor already has the reaction" do
    react("laughing")

    expect(run_node(if_exists: "replace")).to include("changed" => false)
  end

  it "refuses a post the actor can't see, even when nothing would change" do
    post.topic.update!(category: Fabricate(:private_category, group: Fabricate(:group)))

    expect { run_node }.to raise_error(Discourse::InvalidAccess)
  end
end

RSpec.describe DiscourseWorkflows::Nodes::RemoveReaction::V1 do
  include_context "with a post to react to"

  it "removes the actor's reaction", :aggregate_failures do
    react("laughing")

    result = run_node

    expect(result).to include(
      "reaction" => nil,
      "previous_reaction" => "laughing",
      "changed" => true,
    )
    expect(result).to match_node_output_schema(described_class)
    expect(current_reaction).to be_nil
  end

  it "leaves another reaction alone", :aggregate_failures do
    react("hugs")

    expect(run_node).to include("changed" => false)
    expect(current_reaction).to eq("hugs")
  end
end

RSpec.describe DiscourseWorkflows::Nodes::ReactionAdded::V1 do
  include_context "with a post to react to"

  # Built and read right away, as the event listener does: triggers look up the current reaction.
  def trigger_for(trigger_class, &)
    event = DiscourseEvent.track(:post_reaction_toggled, &)
    trigger_class.new(*event[:params]).then { [it.valid?, it.valid? && it.output] }
  end

  it "fires only for its change, without a change key", :aggregate_failures do
    valid, output = trigger_for(described_class) { react("laughing") }
    expect(valid).to be(true)
    expect(output).to include(
      user: include(id: author.id),
      actor: include(id: actor.id),
      reaction: "laughing",
      previous_reaction: nil,
    )
    expect(output).not_to have_key(:change)
    expect(output).to match_node_output_schema(described_class)

    valid, output = trigger_for(DiscourseWorkflows::Nodes::ReactionChanged::V1) { react("hugs") }
    expect(valid).to be(true)
    expect(output).to include(reaction: "hugs", previous_reaction: "laughing")

    valid, output = trigger_for(DiscourseWorkflows::Nodes::ReactionRemoved::V1) { react("hugs") }
    expect(valid).to be(true)
    expect(output).to include(reaction: nil, previous_reaction: "hugs")

    valid, _ = trigger_for(DiscourseWorkflows::Nodes::ReactionRemoved::V1) { react("hugs") }
    expect(valid).to be(false)
  end

  it "hides the generic trigger from the palette, but not the per-change ones",
     :aggregate_failures do
    expect(DiscourseWorkflows::Nodes::PostReactionChanged::V2).not_to be_palette_visible
    expect(described_class).to be_palette_visible
  end
end
