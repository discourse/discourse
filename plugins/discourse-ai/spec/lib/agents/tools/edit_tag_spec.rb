# frozen_string_literal: true

RSpec.describe DiscourseAi::Agents::Tools::EditTag do
  fab!(:llm_model)
  let(:bot_user) { DiscourseAi::AiBot::EntryPoint.find_user_from_model(llm_model.name) }
  let(:llm) { DiscourseAi::Completions::Llm.proxy(llm_model) }
  fab!(:admin)
  fab!(:tag) { Fabricate(:tag, name: "old-name") }

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
    SiteSetting.tagging_enabled = true
  end

  let(:context) { DiscourseAi::Agents::BotContext.new(user: admin) }

  def tool(params = nil, **kwargs)
    params ||= kwargs
    described_class.new(params, bot_user: bot_user, llm: llm, context: context)
  end

  it "renames the tag and logs a staff action attributed to the context user" do
    result = tool(name: "old-name", new_name: "new-name", reason: "Rebranding").invoke

    expect(result[:status]).to eq("success")
    expect(tag.reload.name).to eq("new-name")
    expect(UserHistory.where(acting_user_id: admin.id, custom_type: "renamed_tag").count).to eq(1)
  end

  it "updates the tag description without logging a rename" do
    result = tool(name: "old-name", description: "A better description", reason: "Test").invoke

    expect(result[:status]).to eq("success")
    expect(tag.reload.description).to eq("A better description")
    expect(UserHistory.where(custom_type: "renamed_tag").count).to eq(0)
  end

  it "clears the description when an empty string is provided" do
    tag.update!(description: "Something old")

    result = tool(name: "old-name", description: "", reason: "Cleanup").invoke

    expect(result[:status]).to eq("success")
    expect(tag.reload.description).to be_nil
  end

  it "rejects a new name that normalizes to nothing" do
    result = tool(name: "old-name", new_name: "!!!", reason: "Test").invoke

    expect(result[:status]).to eq("error")
    expect(result[:error]).to include("not a valid tag name")
    expect(tag.reload.name).to eq("old-name")
  end

  it "finds the tag case-insensitively" do
    result = tool(name: "OLD-NAME", description: "Found it", reason: "Test").invoke

    expect(result[:status]).to eq("success")
    expect(tag.reload.description).to eq("Found it")
  end

  it "returns an error when the tag is not found" do
    result = tool(name: "missing", new_name: "whatever", reason: "Test").invoke

    expect(result[:status]).to eq("error")
  end

  it "returns an error when neither new_name nor description is provided" do
    result = tool(name: "old-name", reason: "Test").invoke

    expect(result[:status]).to eq("error")
    expect(result[:error]).to include("new_name or description")
  end

  it "returns an error when reason is blank" do
    result = tool(name: "old-name", new_name: "new-name", reason: " ").invoke

    expect(result[:status]).to eq("error")
  end

  it "returns an error when renaming to an existing tag's name" do
    Fabricate(:tag, name: "taken")

    result = tool(name: "old-name", new_name: "taken", reason: "Test").invoke

    expect(result[:status]).to eq("error")
    expect(tag.reload.name).to eq("old-name")
  end

  it "reports invisible tags as not found" do
    hidden_tag = Fabricate(:tag, name: "staff-only")
    Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: [hidden_tag.name])
    regular_user = Fabricate(:user, trust_level: TrustLevel[0])
    ctx = DiscourseAi::Agents::BotContext.new(user: regular_user)
    t =
      described_class.new(
        { name: hidden_tag.name, new_name: "found-you", reason: "test" },
        bot_user: bot_user,
        llm: llm,
        context: ctx,
      )
    result = t.invoke

    expect(result[:status]).to eq("error")
    expect(result[:error]).to include("not found")
    expect(hidden_tag.reload.name).to eq("staff-only")
  end

  it "returns an error when context user lacks permission" do
    regular_user = Fabricate(:user, trust_level: TrustLevel[0])
    ctx = DiscourseAi::Agents::BotContext.new(user: regular_user)
    t =
      described_class.new(
        { name: "old-name", new_name: "nope", reason: "test" },
        bot_user: bot_user,
        llm: llm,
        context: ctx,
      )
    result = t.invoke

    expect(result[:status]).to eq("error")
    expect(result[:error]).to include("not allowed")
    expect(tag.reload.name).to eq("old-name")
  end
end
