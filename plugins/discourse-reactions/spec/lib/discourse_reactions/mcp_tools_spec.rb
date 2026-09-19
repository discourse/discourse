# frozen_string_literal: true

describe DiscourseReactions::McpTools::SetReaction do
  fab!(:user)
  fab!(:post)

  before do
    SiteSetting.discourse_reactions_enabled = true
    SiteSetting.discourse_reactions_enabled_reactions = "laughing"
  end

  it "rejects a reaction that is not enabled" do
    request_context = instance_double(DiscourseMcp::RequestContext, user:, guardian: user.guardian)

    expect do
      described_class.call(
        arguments: {
          "post_id" => post.id,
          "reaction" => "disabled-reaction",
        },
        request_context:,
      )
    end.to raise_error(DiscourseMcp::ToolError)
    expect(DiscourseReactions::Reaction.find_by(post:, reaction_value: "disabled-reaction")).to eq(
      nil,
    )
  end
end
