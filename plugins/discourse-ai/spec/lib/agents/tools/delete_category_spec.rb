# frozen_string_literal: true

RSpec.describe DiscourseAi::Agents::Tools::DeleteCategory do
  fab!(:llm_model)
  fab!(:bot_user, :admin)
  fab!(:admin)
  fab!(:category)

  let(:llm) { DiscourseAi::Completions::Llm.proxy(llm_model) }
  let(:conversation) do
    Fabricate(:private_message_topic, user: admin, recipient: Discourse.system_user)
  end
  let(:context) { DiscourseAi::Agents::BotContext.new(user: admin, topic: conversation) }

  include_context "with AI bot enabled"

  def tool(params = nil, **kwargs)
    params ||= kwargs
    described_class.new(params, bot_user: bot_user, llm: llm, context: context)
  end

  it "rejects shared conversations without disclosing private categories" do
    category.set_permissions(staff: :full)
    category.save!
    shared_dm = Fabricate(:direct_message_channel, users: [admin, Fabricate(:user)])
    shared_pm = Fabricate(:private_message_topic, user: admin, recipient: Fabricate(:user))
    contexts = [
      DiscourseAi::Agents::BotContext.new(user: admin, channel_id: Fabricate(:chat_channel).id),
      DiscourseAi::Agents::BotContext.new(user: admin, channel_id: shared_dm.id),
      DiscourseAi::Agents::BotContext.new(user: admin, topic: shared_pm),
      DiscourseAi::Agents::BotContext.new(user: admin, topic: Fabricate(:topic)),
    ]

    contexts.each do |shared_context|
      category_tool =
        described_class.new(
          { category_id: category.id, reason: "Unused" },
          bot_user:,
          llm:,
          context: shared_context,
        )

      expect(described_class.available_for_context?(shared_context)).to eq(false)
      expect(category_tool.invoke[:status]).to eq("error")
      expect(category_tool.approval_title).not_to include(category.name)
      expect(category_tool.approval_details).not_to include(category.name)
    end
    expect(Category.exists?(category.id)).to eq(true)
  end

  it "deletes an empty category and logs it as the context user" do
    result = tool(category_id: category.id, reason: "No longer needed").invoke

    expect(result[:status]).to eq("success")
    expect(Category.exists?(category.id)).to eq(false)
    expect(
      UserHistory.exists?(acting_user_id: admin.id, action: UserHistory.actions[:delete_category]),
    ).to eq(true)
  end

  it "previews the deletion without applying it" do
    category_tool = tool(category_id: category.id, reason: "Cleanup")

    expect(category_tool.validation_error).to be_nil
    expect(category_tool.approval_question).to eq("Do you want to delete this category?")
    expect(category_tool.approval_details).to include("can't be undone")

    title =
      Nokogiri::HTML5.fragment(Chat::Message.cook(category_tool.approval_title, user_id: admin.id))
    expect(title.at_css("a.hashtag-cooked")["data-id"]).to eq(category.id.to_s)
    expect(Category.exists?(category.id)).to eq(true)
  end

  it "refuses a category with topics and links to its settings" do
    Fabricate(:topic, category:)

    error = tool(category_id: category.id, reason: "Cleanup").validation_error

    expect(error[:status]).to eq("error")
    expect(error[:error]).to include(
      "still contains 1 topic",
      "#{Discourse.base_url_no_prefix}/c/#{category.slug}/edit/general",
    )
    expect(Category.exists?(category.id)).to eq(true)
  end

  it "counts topics that the cached topic count has not caught up with" do
    Fabricate(:topic, category:)
    category.update_columns(topic_count: 0)

    result = tool(category_id: category.id, reason: "Cleanup").invoke

    expect(result[:status]).to eq("error")
    expect(Category.exists?(category.id)).to eq(true)
  end

  it "ignores the category's own definition topic" do
    category_with_definition = Fabricate(:category_with_definition)

    result = tool(category_id: category_with_definition.id, reason: "Cleanup").invoke

    expect(result[:status]).to eq("success")
    expect(Category.exists?(category_with_definition.id)).to eq(false)
  end

  it "refuses a category with subcategories" do
    Fabricate(:category, parent_category: category)

    error = tool(category_id: category.id, reason: "Cleanup").validation_error

    expect(error[:error]).to include("has subcategories", "/edit/general")
  end

  it "refuses the uncategorized category" do
    error =
      tool(category_id: SiteSetting.uncategorized_category_id, reason: "Cleanup").validation_error

    expect(error[:error]).to include("uncategorized")
  end

  it "returns an error when the category is not found" do
    expect(tool(category_id: -1, reason: "Cleanup").invoke[:status]).to eq("error")
  end

  it "returns an error when reason is blank" do
    expect(tool(category_id: category.id, reason: " ").invoke[:status]).to eq("error")
    expect(Category.exists?(category.id)).to eq(true)
  end

  it "returns an error when the context user cannot edit the category" do
    user = Fabricate(:user)
    topic = Fabricate(:private_message_topic, user:, recipient: Discourse.system_user)
    context = DiscourseAi::Agents::BotContext.new(user:, topic:)
    result =
      described_class.new(
        { category_id: category.id, reason: "Nope" },
        bot_user: bot_user,
        llm: llm,
        context: context,
      ).invoke

    expect(result[:error]).to include("not allowed")
    expect(Category.exists?(category.id)).to eq(true)
  end
end
