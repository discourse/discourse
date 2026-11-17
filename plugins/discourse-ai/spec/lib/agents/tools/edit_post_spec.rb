# frozen_string_literal: true

RSpec.describe DiscourseAi::Agents::Tools::EditPost do
  fab!(:llm_model)
  fab!(:bot_user, :admin)
  let(:llm) { DiscourseAi::Completions::Llm.proxy(llm_model) }
  fab!(:post) { Fabricate(:post, raw: "Original content") }

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
  end

  def tool(params = nil, **kwargs)
    params ||= kwargs
    described_class.new(params, bot_user: bot_user, llm: llm, context: context)
  end

  let(:context) { DiscourseAi::Agents::BotContext.new }

  it "previews content and title changes using the linked post and shared diff fields" do
    post.topic.update!(title: "A [draft] *topic*")
    post_tool =
      tool(
        post_id: post.id,
        raw: "<script>alert('test')</script>\nUpdated content",
        title: "New title",
        edit_reason: "Requested by admin",
      )
    heading = Nokogiri::HTML5.fragment(Chat::Message.cook(post_tool.approval_title))
    expect(heading.at_css("a").text).to eq("#{post.topic.title} · post ##{post.post_number}")
    expect(heading.at_css("a")["href"]).to eq(post.url)
    expect(post_tool.approval_changes).to eq(
      [
        {
          label: "Changing content:",
          before: post.raw,
          after: "<script>alert('test')</script>\nUpdated content",
        },
        { label: "Changing topic title:", before: post.topic.title, after: "New title" },
      ],
    )
    expect(post_tool.approval_parameters).to be_empty
    expect(post.reload.raw).to eq("Original content")
    expect(post.topic.reload.title).to eq("A [draft] *topic*")

    title_tool = tool(post_id: post.id, title: "Another title", edit_reason: "Testing")
    expect(title_tool.approval_changes).to eq(
      [{ label: "Changing topic title:", before: post.topic.title, after: "Another title" }],
    )
  end

  it "falls back to the generic preview when the requester cannot see the post" do
    private_category = Fabricate(:private_category, group: Group[:staff])
    hidden_post =
      Fabricate(:post, raw: "Secret", topic: Fabricate(:topic, category: private_category))
    requester_context = DiscourseAi::Agents::BotContext.new(user: Fabricate(:user))
    post_tool =
      described_class.new(
        { post_id: hidden_post.id, raw: "Changed", edit_reason: "Testing" },
        bot_user: bot_user,
        llm: llm,
        context: requester_context,
      )

    expect(post_tool.approval_title).to eq(post_tool.summary)
    expect(post_tool.approval_changes).to be_empty
  end

  it "falls back to the generic preview when the post's topic was deleted" do
    post.topic.trash!(Discourse.system_user)
    post_tool = tool(post_id: post.id, raw: "Changed", edit_reason: "Testing")

    expect(post_tool.approval_title).to eq(post_tool.summary)
    expect(post_tool.approval_changes).to be_empty
  end

  it "edits the post content" do
    result = tool(post_id: post.id, raw: "Updated content", edit_reason: "Fixing typo").invoke

    expect(result[:status]).to eq("success")
    expect(post.reload.raw).to eq("Updated content")
    expect(post.edit_reason).to be_nil
  end

  it "sets a public edit reason when public_edit_reason is true" do
    result =
      tool(
        post_id: post.id,
        raw: "Updated content",
        edit_reason: "Fixing typo",
        public_edit_reason: true,
      ).invoke

    expect(result[:status]).to eq("success")
    expect(post.reload.edit_reason).to eq("Fixing typo")
  end

  it "edits the topic title via the first post" do
    first_post = post.topic.first_post

    result =
      tool(post_id: first_post.id, title: "New Topic Title", edit_reason: "Better title").invoke

    expect(result[:status]).to eq("success")
    expect(first_post.topic.reload.title).to eq("New Topic Title")
  end

  it "edits the post a topic URL points at, defaulting to the first post" do
    reply = Fabricate(:post, topic: post.topic, raw: "Original reply content")

    reply_result =
      tool(
        topic_id: post.topic_id,
        post_number: reply.post_number,
        raw: "Updated reply content",
        edit_reason: "Requested by admin",
      ).invoke
    first_post_result =
      tool(
        topic_id: post.topic_id,
        raw: "Updated first post content",
        edit_reason: "Requested by admin",
      ).invoke

    expect([reply_result[:status], first_post_result[:status]]).to eq(%w[success success])
    expect(reply.reload.raw).to eq("Updated reply content")
    expect(post.reload.raw).to eq("Updated first post content")
  end

  it "queues an edit addressed by a topic URL and applies it to that post on approval" do
    enable_dsa_reporting
    reply = Fabricate(:post, topic: post.topic, raw: "Original reply content")
    agent = Fabricate(:ai_agent, require_approval: true, tools: [["EditPost", nil, false]])
    tool_call =
      DiscourseAi::Completions::ToolCall.new(
        id: "edit-1",
        name: "edit_post",
        parameters: {
          topic_id: post.topic_id,
          post_number: reply.post_number,
          raw: "Corrected reply content",
          edit_reason: "Requested by admin",
        },
      )
    context =
      DiscourseAi::Agents::BotContext.new(
        user: bot_user,
        messages: [{ type: :user, content: "Edit #{reply.full_url}" }],
      )

    DiscourseAi::Completions::Llm.with_prepared_responses([tool_call, "Queued for approval"]) do
      DiscourseAi::Agents::Bot
        .as(bot_user, agent: agent.class_instance.new, model: llm_model)
        .reply(context) { |_partial| }
    end
    expect(reply.reload.raw).to eq("Original reply content")

    expect(ReviewableAiToolAction.last.perform(Fabricate(:admin), :approve)).to be_success
    expect(reply.reload.raw).to eq("Corrected reply content")
  end

  describe "#validation_error" do
    it "rejects a request that names no post, or names it both by ID and by topic" do
      no_target = tool(raw: "Content", edit_reason: "Reason").validation_error
      both_targets =
        tool(
          post_id: post.id,
          topic_id: post.topic_id,
          raw: "Content",
          edit_reason: "Reason",
        ).validation_error

      expect([no_target[:status], both_targets[:status]]).to eq(%w[error error])
    end

    it "rejects a post number given with a post ID instead of a topic ID" do
      error =
        tool(
          post_id: post.id,
          post_number: 2,
          raw: "Content",
          edit_reason: "Reason",
        ).validation_error

      expect(error[:status]).to eq("error")
    end

    it "rejects a request that changes nothing or gives no reason before it can be queued" do
      nothing_to_edit = tool(post_id: post.id, edit_reason: "Reason").validation_error
      no_reason = tool(post_id: post.id, raw: "Content", edit_reason: " ").validation_error

      expect([nothing_to_edit[:status], no_reason[:status]]).to eq(%w[error error])
    end
  end

  it "returns an error when post is not found" do
    result = tool(post_id: -1, raw: "Content", edit_reason: "Reason").invoke

    expect(result[:status]).to eq("error")
  end

  it "returns an error when neither raw nor title is provided" do
    result = tool(post_id: post.id, edit_reason: "No changes").invoke

    expect(result[:status]).to eq("error")
  end

  it "returns an error when edit_reason is blank" do
    result = tool(post_id: post.id, raw: "Content", edit_reason: " ").invoke

    expect(result[:status]).to eq("error")
  end

  it "returns an error when context user lacks permission" do
    regular_user = Fabricate(:user, trust_level: TrustLevel[0])
    other_post = Fabricate(:post)
    ctx = DiscourseAi::Agents::BotContext.new(user: regular_user)
    t =
      described_class.new(
        { post_id: other_post.id, raw: "New content", edit_reason: "test" },
        bot_user: bot_user,
        llm: llm,
        context: ctx,
      )
    result = t.invoke

    expect(result[:status]).to eq("error")
    expect(result[:error]).to include("not allowed")
  end
end
