# frozen_string_literal: true

RSpec.describe DiscourseAi::Agents::Tools::CreateTag do
  fab!(:llm_model)
  let(:bot_user) { DiscourseAi::AiBot::EntryPoint.find_user_from_model(llm_model.name) }
  let(:llm) { DiscourseAi::Completions::Llm.proxy(llm_model) }
  fab!(:admin)

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

  it "creates a tag with a description" do
    result =
      tool(name: "release-notes", description: "Release announcements", reason: "Setup").invoke

    expect(result[:status]).to eq("success")
    tag = Tag.find_by_name("release-notes")
    expect(tag).to be_present
    expect(tag.description).to eq("Release announcements")
    expect(result[:tag_name]).to eq("release-notes")
  end

  it "cleans the tag name like manual tag creation does" do
    result = tool(name: "Release Notes!", reason: "Setup").invoke

    expect(result[:status]).to eq("success")
    expect(result[:tag_name]).to eq("release-notes")
  end

  it "logs a staff action attributed to the context user" do
    expect { tool(name: "audited-tag", reason: "Audit trail").invoke }.to change {
      UserHistory.where(acting_user_id: admin.id, custom_type: "created_tag").count
    }.by(1)
  end

  it "returns an error when the tag already exists" do
    Fabricate(:tag, name: "duplicate")

    result = tool(name: "Duplicate", reason: "Test").invoke

    expect(result[:status]).to eq("error")
    expect(result[:error]).to include("already exists")
  end

  it "returns an error when the name is blank" do
    result = tool(name: " ", reason: "Test").invoke

    expect(result[:status]).to eq("error")
  end

  it "returns an error when reason is blank" do
    result = tool(name: "no-reason", reason: " ").invoke

    expect(result[:status]).to eq("error")
  end

  it "returns an error when tagging is disabled" do
    SiteSetting.tagging_enabled = false

    result = tool(name: "some-tag", reason: "Test").invoke

    expect(result[:status]).to eq("error")
    expect(Tag.exists?(name: "some-tag")).to eq(false)
  end

  it "does not reveal whether a tag exists to users lacking permission" do
    Fabricate(:tag, name: "hidden-existing")
    regular_user = Fabricate(:user, trust_level: TrustLevel[0])
    ctx = DiscourseAi::Agents::BotContext.new(user: regular_user)
    t =
      described_class.new(
        { name: "hidden-existing", reason: "test" },
        bot_user: bot_user,
        llm: llm,
        context: ctx,
      )
    result = t.invoke

    expect(result[:status]).to eq("error")
    expect(result[:error]).to include("not allowed")
    expect(result[:error]).not_to include("already exists")
  end

  it "returns an error when context user lacks permission" do
    regular_user = Fabricate(:user, trust_level: TrustLevel[0])
    ctx = DiscourseAi::Agents::BotContext.new(user: regular_user)
    t =
      described_class.new(
        { name: "nope", reason: "test" },
        bot_user: bot_user,
        llm: llm,
        context: ctx,
      )
    result = t.invoke

    expect(result[:status]).to eq("error")
    expect(result[:error]).to include("not allowed")
    expect(Tag.exists?(name: "nope")).to eq(false)
  end
end
