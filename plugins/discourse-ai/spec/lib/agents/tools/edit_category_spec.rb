# frozen_string_literal: true

RSpec.describe DiscourseAi::Agents::Tools::EditCategory do
  fab!(:llm_model)
  fab!(:bot_user, :admin)
  let(:llm) { DiscourseAi::Completions::Llm.proxy(llm_model) }
  fab!(:admin)
  fab!(:category)

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
  end

  let(:context) { DiscourseAi::Agents::BotContext.new(user: admin) }

  def tool(params = nil, **kwargs)
    params ||= kwargs
    described_class.new(params, bot_user: bot_user, llm: llm, context: context)
  end

  describe "#details" do
    it "renders the edited fields and a category badge in chat for a subcategory" do
      subcategory = Fabricate(:category, parent_category: category)
      details =
        tool(
          category_id: subcategory.id,
          name: "New name",
          color: "FF0000",
          reason: "Rebranding",
        ).details

      cooked = Nokogiri::HTML5.fragment(Chat::Message.cook(details, user_id: admin.id))

      expect(cooked.css("code").map(&:text)).to eq(%w[name color])
      badge = cooked.at_css("a.hashtag-cooked[data-type='category']")
      expect(badge["data-id"]).to eq(subcategory.id.to_s)
      expect(badge["href"]).to eq(subcategory.url)
      expect(badge.text).to include(subcategory.name)
    end
  end

  describe "#approval_details" do
    it "shows the current and proposed values without applying the changes" do
      category.update!(name: "Storm", description: "Old description")
      category_tool =
        tool(
          category_id: category.id,
          name: "Wind & Rain",
          description: "<script>alert('test')</script>",
          reason: "Rebranding",
        )

      cooked =
        Nokogiri::HTML5.fragment(
          Chat::Message.cook(category_tool.approval_details, user_id: admin.id),
        )

      expect(category_tool.summary).to eq("Edit category name and description")

      expect(cooked.css("code").map(&:text)).to eq(
        [
          "name",
          "Storm",
          "Wind & Rain",
          "description",
          "Old description",
          "<script>alert('test')</script>",
        ],
      )
      expect(cooked.css("script")).to be_empty
      expect(category_tool.approval_changes).to eq(
        [
          { label: "Changing name:", before: "Storm", after: "Wind & Rain" },
          {
            label: "Changing description:",
            before: "Old description",
            after: "<script>alert('test')</script>",
          },
        ],
      )
      expect(category_tool.approval_question).to eq("Do you want to make this change?")
      expect(category.reload.name).to eq("Storm")

      question =
        Nokogiri::HTML5.fragment(
          Chat::Message.cook(category_tool.approval_title, user_id: admin.id),
        )
      expect(question.at_css("a.hashtag-cooked")["data-id"]).to eq(category.id.to_s)
    end
  end

  it "updates the category's name and colors" do
    result =
      tool(
        category_id: category.id,
        name: "Renamed category",
        color: "#FF0000",
        text_color: "000000",
        reason: "Rebranding",
      ).invoke

    expect(result[:status]).to eq("success")
    category.reload
    expect(category.name).to eq("Renamed category")
    expect(category.color).to eq("FF0000")
    expect(category.text_color).to eq("000000")
  end

  it "updates the category description and its definition topic" do
    category_with_definition = Fabricate(:category_with_definition)

    result =
      tool(
        category_id: category_with_definition.id,
        description: "A brand new description",
        reason: "Test",
      ).invoke

    expect(result[:status]).to eq("success")
    category_with_definition.reload
    expect(category_with_definition.description).to include("A brand new description")
    expect(category_with_definition.topic.first_post.reload.raw).to eq("A brand new description")
  end

  it "clears the description when an empty string is provided" do
    category_with_definition = Fabricate(:category_with_definition)
    tool(
      category_id: category_with_definition.id,
      description: "Something old",
      reason: "Setup",
    ).invoke

    result = tool(category_id: category_with_definition.id, description: "", reason: "Clean").invoke

    expect(result[:status]).to eq("success")
    expect(category_with_definition.reload.description).to be_blank
  end

  it "rejects invalid changes before they can be queued for approval" do
    error = tool(category_id: category.id, color: "not-a-color", reason: "Test").validation_error

    expect(error).to be_present
    expect(error[:status]).to eq("error")
    expect(category.reload.color).not_to eq("not-a-color")
  end

  it "logs a staff action attributed to the context user" do
    expect {
      tool(category_id: category.id, name: "Audited name", reason: "Audit trail").invoke
    }.to change {
      UserHistory.where(
        acting_user_id: admin.id,
        action: UserHistory.actions[:change_category_settings],
      ).count
    }.by(1)
  end

  it "logs a staff action for a description-only edit" do
    expect {
      tool(category_id: category.id, description: "Audited description", reason: "Audit").invoke
    }.to change {
      UserHistory.where(
        acting_user_id: admin.id,
        action: UserHistory.actions[:change_category_settings],
        subject: "description",
      ).count
    }.by(1)
  end

  it "returns an error when the category is not found" do
    result = tool(category_id: -1, name: "New name", reason: "Test").invoke

    expect(result[:status]).to eq("error")
  end

  it "returns an error when no editable field is provided" do
    result = tool(category_id: category.id, reason: "Test").invoke

    expect(result[:status]).to eq("error")
    expect(result[:error]).to include("At least one")
  end

  it "does not queue a category edit when the requested values are already applied" do
    category_tool = tool(category_id: category.id, name: category.name, reason: "Repeat request")

    expect(category_tool.validation_error).to include(status: "error")
    expect(category_tool.approval_details).to be_empty
  end

  it "does not queue a description edit that only repeats stored HTML as Markdown" do
    category.update_columns(description: "<p>Same description.</p>")
    category_tool =
      tool(category_id: category.id, description: "Same description.", reason: "Repeat request")

    expect(category_tool.validation_error).to include(status: "error")
    expect(category_tool.approval_details).to be_empty
  end

  it "previews the description's Markdown source rather than its cooked HTML" do
    category_with_topic = Fabricate(:category_with_definition)
    category_with_topic.update!(description: "Old **description**")
    expect(category_with_topic.reload.description).to include("Old <strong>description</strong>")

    category_tool =
      tool(
        category_id: category_with_topic.id,
        description: "New description",
        reason: "Rebranding",
      )
    expect(category_tool.approval_changes).to eq(
      [{ label: "Changing description:", before: "Old **description**", after: "New description" }],
    )

    repeat_tool =
      tool(
        category_id: category_with_topic.id,
        description: "Old **description**",
        reason: "Repeat request",
      )
    expect(repeat_tool.validation_error).to include(status: "error")
  end

  it "returns an error when reason is blank" do
    result = tool(category_id: category.id, name: "New name", reason: " ").invoke

    expect(result[:status]).to eq("error")
  end

  it "returns an error when the new values are invalid" do
    result = tool(category_id: category.id, color: "not-a-color", reason: "Test").invoke

    expect(result[:status]).to eq("error")
    expect(category.reload.color).not_to eq("not-a-color")
  end

  it "returns an error when context user lacks permission" do
    regular_user = Fabricate(:user, trust_level: TrustLevel[0])
    ctx = DiscourseAi::Agents::BotContext.new(user: regular_user)
    t =
      described_class.new(
        { category_id: category.id, name: "Nope", reason: "test" },
        bot_user: bot_user,
        llm: llm,
        context: ctx,
      )
    result = t.invoke

    expect(result[:status]).to eq("error")
    expect(result[:error]).to include("not allowed")
    expect(category.reload.name).not_to eq("Nope")
  end
end
