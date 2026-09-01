# frozen_string_literal: true

RSpec.describe DiscourseAi::Agents::Tools::CreateCategory do
  fab!(:llm_model)
  let(:bot_user) { DiscourseAi::AiBot::EntryPoint.find_user_from_model(llm_model.name) }
  let(:llm) { DiscourseAi::Completions::Llm.proxy(llm_model) }
  fab!(:admin)

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
  end

  let(:context) { DiscourseAi::Agents::BotContext.new(user: admin) }

  def tool(params = nil, **kwargs)
    params ||= kwargs
    described_class.new(params, bot_user: bot_user, llm: llm, context: context)
  end

  it "creates a category with a description and returns its id and url" do
    result =
      tool(name: "What we do", description: "All about our mission", reason: "Site setup").invoke

    expect(result[:status]).to eq("success")

    category = Category.find(result[:category_id])
    expect(category.name).to eq("What we do")
    expect(category.user_id).to eq(admin.id)
    expect(category.description).to include("All about our mission")
    expect(result[:url]).to eq(category.url)
  end

  it "creates a subcategory under the given parent" do
    parent = Fabricate(:category)

    result =
      tool(name: "How to use the forum", parent_category_id: parent.id, reason: "Setup").invoke

    expect(result[:status]).to eq("success")
    expect(Category.find(result[:category_id]).parent_category_id).to eq(parent.id)
  end

  it "applies custom colors, stripping a leading # from hex codes" do
    result = tool(name: "Colorful", color: "#AA2211", text_color: "EEEEEE", reason: "Setup").invoke

    expect(result[:status]).to eq("success")
    category = Category.find(result[:category_id])
    expect(category.color).to eq("AA2211")
    expect(category.text_color).to eq("EEEEEE")
  end

  it "logs a staff action attributed to the context user" do
    expect { tool(name: "Audited", reason: "Audit trail").invoke }.to change {
      UserHistory.where(
        acting_user_id: admin.id,
        action: UserHistory.actions[:create_category],
      ).count
    }.by(1)
  end

  it "returns an error when the description is too long" do
    result = tool(name: "Long desc", description: "a" * 1001, reason: "Test").invoke

    expect(result[:status]).to eq("error")
    expect(Category.exists?(name: "Long desc")).to eq(false)
  end

  it "returns an error when name is blank" do
    result = tool(name: " ", reason: "Test").invoke

    expect(result[:status]).to eq("error")
  end

  it "returns an error when the parent category is not found" do
    result = tool(name: "Orphan", parent_category_id: -1, reason: "Test").invoke

    expect(result[:status]).to eq("error")
    expect(result[:error]).to include("Parent category not found")
  end

  it "returns an error when reason is blank" do
    result = tool(name: "No reason", reason: " ").invoke

    expect(result[:status]).to eq("error")
  end

  it "rejects a duplicate name before it can be queued for approval" do
    Fabricate(:category, name: "Duplicate")

    tool_instance = tool(name: "Duplicate", reason: "Test")

    expect(tool_instance.validation_error).to be_present
    expect(tool_instance.invoke[:status]).to eq("error")
  end

  it "rejects an invalid color before it can be queued for approval" do
    error = tool(name: "Bad color", color: "nope", reason: "Test").validation_error

    expect(error).to be_present
    expect(Category.exists?(name: "Bad color")).to eq(false)
  end

  it "returns an error when context user lacks permission" do
    regular_user = Fabricate(:user, trust_level: TrustLevel[0])
    ctx = DiscourseAi::Agents::BotContext.new(user: regular_user)
    t =
      described_class.new(
        { name: "Nope", reason: "test" },
        bot_user: bot_user,
        llm: llm,
        context: ctx,
      )
    result = t.invoke

    expect(result[:status]).to eq("error")
    expect(result[:error]).to include("not allowed")
    expect(Category.exists?(name: "Nope")).to eq(false)
  end
end
