# frozen_string_literal: true

RSpec.describe UserSerializer do
  fab!(:admin)
  fab!(:eligible_user, :user)
  fab!(:other_user, :user)
  fab!(:group) { Fabricate(:group, users: [eligible_user]) }
  fab!(:llm_model)
  fab!(:agent) { Fabricate(:ai_agent, allowed_group_ids: [group.id], default_llm_id: llm_model.id) }

  before do
    enable_current_plugin
    enable_legacy_discover
    SiteSetting.ai_discover_agent = agent.id
    SiteSetting.ai_ask_ai_enabled = true
    SiteSetting.ai_ask_ai_agent = agent.id
    SiteSetting.ai_ask_ai_allowed_groups = group.id.to_s
  end

  def serialize(user, viewer)
    described_class.new(user, scope: viewer.guardian, root: false).as_json
  end

  it "serializes the viewed user's AI eligibility" do
    expect(serialize(eligible_user, admin)).to include(
      can_use_ask_ai: true,
      can_use_ai_discover_agent: true,
    )

    expect(serialize(other_user, admin)).to include(
      can_use_ask_ai: false,
      can_use_ai_discover_agent: false,
    )
  end

  it "includes AI eligibility only for users who can edit the viewed user" do
    json = serialize(eligible_user, other_user)

    expect(json).not_to have_key(:can_use_ask_ai)
    expect(json).not_to have_key(:can_use_ai_discover_agent)
  end
end
