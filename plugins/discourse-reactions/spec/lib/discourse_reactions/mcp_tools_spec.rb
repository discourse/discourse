# frozen_string_literal: true

describe DiscourseReactions::McpTools::SetReaction do
  fab!(:user)
  fab!(:post)

  let(:request_context) { instance_double(DiscourseMcp::RequestContext, guardian: user.guardian) }

  before do
    SiteSetting.discourse_reactions_enabled = true
    SiteSetting.discourse_reactions_enabled_reactions = "laughing"
  end

  def set_reaction(reaction)
    described_class.call(
      arguments: {
        "post_id" => post.id,
        "reaction" => reaction,
      },
      request_context:,
    )
  end

  it "reacts to the post" do
    expect(set_reaction("laughing")).to include(
      structuredContent: {
        post_id: post.id,
        reaction: "laughing",
      },
    )
    expect(DiscourseReactions::ReactionManager.reaction_value_for(user:, post:)).to eq("laughing")
  end

  it "rejects a reaction that is not enabled" do
    expect { set_reaction("disabled-reaction") }.to raise_error(DiscourseMcp::ToolError)
  end
end
