# frozen_string_literal: true

return unless defined?(::Assigner)

RSpec.describe DiscourseAi::Agents::Tools::Assign do
  fab!(:llm_model)
  let(:bot_user) { DiscourseAi::AiBot::EntryPoint.find_user_from_model(llm_model.name) }
  let(:llm) { DiscourseAi::Completions::Llm.proxy(llm_model) }
  fab!(:post)
  fab!(:user, :admin)
  fab!(:group)

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
    SiteSetting.assign_enabled = true
  end

  def tool(params = nil, **kwargs)
    params ||= kwargs
    described_class.new(params, bot_user: bot_user, llm: llm, context: context)
  end

  let(:context) { DiscourseAi::Agents::BotContext.new }
  let(:topic) { post.topic }

  it "assigns the topic to a user" do
    result =
      tool(
        topic_id: topic.id,
        assigned: true,
        username: user.username,
        reason: "Needs attention",
      ).invoke

    expect(result[:status]).to eq("success")
    expect(topic.reload.assignment).to be_present
    expect(topic.assignment.assigned_to).to eq(user)
  end

  it "assigns the topic to a group" do
    group.update!(assignable_level: Group::ALIAS_LEVELS[:everyone])

    result =
      tool(
        topic_id: topic.id,
        assigned: true,
        group_name: group.name,
        reason: "Team responsibility",
      ).invoke

    expect(result[:status]).to eq("success")
    expect(topic.reload.assignment).to be_present
    expect(topic.assignment.assigned_to).to eq(group)
  end

  it "unassigns the topic" do
    ::Assigner.new(topic, Discourse.system_user).assign(user)

    result = tool(topic_id: topic.id, assigned: false, reason: "No longer needed").invoke

    expect(result[:status]).to eq("success")
    expect(topic.reload.assignment).to be_nil
  end

  it "returns an error when topic is not found" do
    result = tool(topic_id: -1, assigned: true, username: user.username, reason: "Test").invoke

    expect(result[:status]).to eq("error")
  end

  it "returns an error when assignee is not found" do
    result =
      tool(topic_id: topic.id, assigned: true, username: "nonexistent", reason: "Test").invoke

    expect(result[:status]).to eq("error")
  end

  it "returns an error when reason is blank" do
    result = tool(topic_id: topic.id, assigned: true, username: user.username, reason: " ").invoke

    expect(result[:status]).to eq("error")
  end

  it "returns an error when context user lacks permission" do
    regular_user = Fabricate(:user, trust_level: TrustLevel[0])
    ctx = DiscourseAi::Agents::BotContext.new(user: regular_user)
    t =
      described_class.new(
        { topic_id: topic.id, assigned: true, username: user.username, reason: "test" },
        bot_user: bot_user,
        llm: llm,
        context: ctx,
      )
    result = t.invoke

    expect(result[:status]).to eq("error")
    expect(result[:error]).to include("not allowed")
  end
end
