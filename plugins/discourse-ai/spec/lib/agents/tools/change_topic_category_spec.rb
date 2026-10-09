# frozen_string_literal: true

RSpec.describe DiscourseAi::Agents::Tools::ChangeTopicCategory do
  fab!(:llm_model)
  fab!(:bot_user, :admin)
  let(:llm) { DiscourseAi::Completions::Llm.proxy(llm_model) }
  fab!(:post)
  fab!(:category)
  fab!(:target_category, :category)

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
  end

  def tool(params = nil, **kwargs)
    params ||= kwargs
    described_class.new(params, bot_user: bot_user, llm: llm, context: context)
  end

  let(:context) { DiscourseAi::Agents::BotContext.new }

  it "previews the topic title and category names and colors without moving it" do
    topic = post.topic
    topic.update!(title: "A [draft] *topic*", category: category)
    category_tool = tool(topic_id: topic.id, category_id: target_category.id, reason: "Better fit")
    title = Nokogiri::HTML5.fragment(Chat::Message.cook(category_tool.approval_title))
    expect(title.at_css("a").text).to eq(topic.title)
    expect(title.at_css("a")["href"]).to eq(topic.url)
    expect(category_tool.approval_changes).to eq(
      [
        {
          label: "Changing category:",
          before: category.name,
          after: target_category.name,
          before_color: category.color,
          after_color: target_category.color,
        },
      ],
    )
    expect(category_tool.approval_parameters).to be_empty
    expect(topic.reload.category_id).to eq(category.id)
  end

  it "moves the topic to a different category" do
    topic = post.topic
    topic.update!(category: category)

    result = tool(topic_id: topic.id, category_id: target_category.id, reason: "Better fit").invoke

    expect(result[:status]).to eq("success")
    expect(topic.reload.category_id).to eq(target_category.id)
    expect(post.reload.edit_reason).to be_nil
  end

  it "sets a public edit reason when public_edit_reason is true" do
    topic = post.topic
    topic.update!(category: category)

    result =
      tool(
        topic_id: topic.id,
        category_id: target_category.id,
        reason: "Better fit",
        public_edit_reason: true,
      ).invoke

    expect(result[:status]).to eq("success")
    expect(post.reload.edit_reason).to eq("Better fit")
  end

  it "returns an error when topic is not found" do
    result = tool(topic_id: -1, category_id: target_category.id, reason: "Test").invoke

    expect(result[:status]).to eq("error")
  end

  it "rejects missing topics, categories, and reasons before queueing for approval" do
    expect(
      tool(topic_id: -1, category_id: target_category.id, reason: "Test").validation_error,
    ).to be_present
    expect(
      tool(topic_id: post.topic_id, category_id: -1, reason: "Test").validation_error,
    ).to be_present
    expect(
      tool(topic_id: post.topic_id, category_id: target_category.id, reason: " ").validation_error,
    ).to be_present
    expect(
      tool(topic_id: post.topic_id, category_id: target_category.id, reason: "Ok").validation_error,
    ).to be_nil
  end

  it "returns an error when category is not found" do
    result = tool(topic_id: post.topic_id, category_id: -1, reason: "Test").invoke

    expect(result[:status]).to eq("error")
  end

  it "returns an error when reason is blank" do
    result = tool(topic_id: post.topic_id, category_id: target_category.id, reason: " ").invoke

    expect(result[:status]).to eq("error")
  end

  it "returns an error when context user lacks permission" do
    regular_user = Fabricate(:user, trust_level: TrustLevel[0])
    ctx = DiscourseAi::Agents::BotContext.new(user: regular_user)
    t =
      described_class.new(
        { topic_id: post.topic_id, category_id: target_category.id, reason: "test" },
        bot_user: bot_user,
        llm: llm,
        context: ctx,
      )
    result = t.invoke

    expect(result[:status]).to eq("error")
    expect(result[:error]).to include("not allowed")
  end
end
