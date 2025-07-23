# frozen_string_literal: true

return if !defined?(DiscourseAutomation)

describe DiscourseAi::Automation::LlmPersonaTriage do
  fab!(:user)
  fab!(:bot_user) { Fabricate(:user) }

  fab!(:llm_model) { Fabricate(:anthropic_model, name: "claude-3-opus", enabled_chat_bot: true) }

  fab!(:ai_persona) do
    persona =
      Fabricate(
        :ai_persona,
        name: "Triage Helper",
        description: "A persona that helps with triaging posts",
        system_prompt: "You are a helpful assistant that triages posts",
        default_llm: llm_model,
      )

    # Create the user for this persona
    persona.update!(user_id: bot_user.id)
    persona
  end

  let(:automation) do
    Fabricate(:automation, name: "my automation", script: "llm_persona_triage", enabled: true)
  end

  def add_automation_field(name, value, type: "text")
    automation.fields.create!(
      component: type,
      name: name,
      metadata: {
        value: value,
      },
      target: "script",
    )
  end

  before do
    enable_current_plugin

    SiteSetting.ai_bot_enabled = true
    SiteSetting.ai_bot_allowed_groups = "#{Group::AUTO_GROUPS[:trust_level_0]}"

    add_automation_field("persona", ai_persona.id, type: "choices")
    add_automation_field("whisper", false, type: "boolean")
  end

  it "can respond to a post using the specified persona" do
    post = Fabricate(:post, raw: "This is a test post that needs triage")

    response_text = "I analyzed your post and can help with that."

    body = (<<~STRING).strip
      event: message_start
      data: {"type": "message_start", "message": {"id": "msg_1nZdL29xx5MUA1yADyHTEsnR8uuvGzszyY", "type": "message", "role": "assistant", "content": [], "model": "claude-3-opus-20240229", "stop_reason": null, "stop_sequence": null, "usage": {"input_tokens": 25, "output_tokens": 1}}}

      event: content_block_start
      data: {"type": "content_block_start", "index":0, "content_block": {"type": "text", "text": ""}}

      event: ping
      data: {"type": "ping"}

      event: content_block_delta
      data: {"type": "content_block_delta", "index": 0, "delta": {"type": "text_delta", "text": "#{response_text}"}}

      event: content_block_stop
      data: {"type": "content_block_stop", "index": 0}

      event: message_delta
      data: {"type": "message_delta", "delta": {"stop_reason": "end_turn", "stop_sequence":null, "usage":{"output_tokens": 15}}}

      event: message_stop
      data: {"type": "message_stop"}
    STRING

    stub_request(:post, "https://api.anthropic.com/v1/messages").to_return(body: body)

    automation.running_in_background!
    automation.trigger!({ "post" => post })

    log = AiApiAuditLog.last
    expect(log).to be_present
    expect(log.user_id).to eq(post.user_id)
    expect(log.feature_name).to eq("automation - #{automation.name}")

    topic = post.topic.reload
    last_post = topic.posts.order(:post_number).last

    expect(topic.posts.count).to eq(2)

    # Verify that the response was posted by the persona's user
    expect(last_post.user_id).to eq(bot_user.id)
    expect(last_post.raw).to eq(response_text)
    expect(last_post.post_type).to eq(Post.types[:regular]) # Not a whisper
  end

  it "can respond with a whisper when configured to do so" do
    add_automation_field("whisper", true, type: "boolean")
    post = Fabricate(:post, raw: "This is another test post for triage")

    response_text = "Staff-only response to your post."

    DiscourseAi::Completions::Llm.with_prepared_responses([response_text]) do
      automation.running_in_background!
      automation.trigger!({ "post" => post })
    end

    topic = post.topic.reload
    last_post = topic.posts.order(:post_number).last

    # Verify that the response is a whisper
    expect(last_post.user_id).to eq(bot_user.id)
    expect(last_post.raw).to eq(response_text)
    expect(last_post.post_type).to eq(Post.types[:whisper]) # This should be a whisper
  end

  it "does not respond to posts made by bots" do
    bot = Fabricate(:bot)
    bot_post = Fabricate(:post, user: bot, raw: "This is a bot post")

    # The automation should not trigger for bot posts
    DiscourseAi::Completions::Llm.with_prepared_responses(["Response"]) do
      automation.running_in_background!
      automation.trigger!({ "post" => bot_post })
    end

    # Verify no new post was created
    expect(bot_post.topic.reload.posts.count).to eq(1)
  end

  it "handles errors gracefully" do
    post = Fabricate(:post, raw: "Error-triggering post")

    # Set up to cause an error
    ai_persona.update!(user_id: nil)

    # Should not raise an error
    expect {
      automation.running_in_background!
      automation.trigger!({ "post" => post })
    }.not_to raise_error

    # Verify no new post was created
    expect(post.topic.reload.posts.count).to eq(1)
  end

  it "passes topic metadata in context when responding to topic" do
    # Create a category and tags for the test
    category = Fabricate(:category, name: "Test Category")
    tag1 = Fabricate(:tag, name: "test-tag")
    tag2 = Fabricate(:tag, name: "support")

    # Create a topic with category and tags
    topic =
      Fabricate(
        :topic,
        title: "Important Question About Feature",
        category: category,
        tags: [tag1, tag2],
        user: user,
      )

    # Create a post in that topic
    _post =
      Fabricate(
        :post,
        topic: topic,
        user: user,
        raw: "This is a test post in a categorized and tagged topic",
      )

    post2 =
      Fabricate(:post, topic: topic, user: user, raw: "This is another post in the same topic")

    # Capture the prompt sent to the LLM to verify it contains metadata
    prompt = nil

    DiscourseAi::Completions::Llm.with_prepared_responses(
      ["I've analyzed your question"],
    ) do |_, _, _prompts|
      automation.running_in_background!
      automation.trigger!({ "post" => post2 })
      prompt = _prompts.first
    end

    context = prompt.messages[1][:content] # The second message should be the triage prompt

    # Verify that topic metadata is included in the context
    expect(context).to include("Important Question About Feature")
    expect(context).to include("Test Category")
    expect(context).to include("test-tag")
    expect(context).to include("support")
  end

  it "interacts correctly with a PM with no replies" do
    pm_topic = Fabricate(:private_message_topic, user: user, title: "Important PM")

    # Create initial PM post
    pm_post =
      Fabricate(
        :post,
        topic: pm_topic,
        user: user,
        raw: "This is a private message that needs triage",
      )

    DiscourseAi::Completions::Llm.with_prepared_responses(
      ["I've received your private message"],
    ) do |_, _, _prompts|
      automation.running_in_background!
      automation.trigger!({ "post" => pm_post })
    end

    reply = pm_topic.posts.order(:post_number).last
    expect(reply.raw).to eq("I've received your private message")
    expect(reply.topic.reload.title).to eq("Important PM")
  end

  it "interacts correctly with PMs" do
    # Create a private message topic
    pm_topic = Fabricate(:private_message_topic, user: user, title: "Important PM")

    # Create initial PM post
    pm_post =
      Fabricate(
        :post,
        topic: pm_topic,
        user: user,
        raw: "This is a private message that needs triage",
      )

    # Create a follow-up post
    pm_post2 =
      Fabricate(
        :post,
        topic: pm_topic,
        user: user,
        raw: "Adding more context to my private message",
      )

    # Capture the prompt sent to the LLM
    prompt = nil

    original_user_ids = pm_topic.topic_allowed_users.pluck(:user_id)

    DiscourseAi::Completions::Llm.with_prepared_responses(
      ["I've received your private message"],
    ) do |_, _, _prompts|
      automation.running_in_background!
      automation.trigger!({ "post" => pm_post2 })
      prompt = _prompts.first
    end

    context = prompt.messages[1][:content]

    # Verify that PM metadata is included in the context
    expect(context).to include("Important PM")
    expect(context).to include(pm_post.raw)
    expect(context).to include(pm_post2.raw)

    reply = pm_topic.posts.order(:post_number).last
    expect(reply.raw).to eq("I've received your private message")

    topic = reply.topic

    # should not inject persona into allowed users
    expect(topic.topic_allowed_users.pluck(:user_id).sort).to eq(original_user_ids.sort)
  end

  describe "LLM Persona Triage with Chat Message Creation" do
    fab!(:user)
    fab!(:bot_user) { Fabricate(:user) }
    fab!(:chat_channel) { Fabricate(:category_channel) }

    fab!(:custom_tool) do
      AiTool.create!(
        name: "Chat Notifier",
        tool_name: "chat_notifier",
        description: "Creates a chat notification in a channel",
        parameters: [
          { name: "channel_id", type: "integer", description: "Chat channel ID" },
          { name: "message", type: "string", description: "Message to post" },
        ],
        script: <<~JS,
        function invoke(params) {
          // Create a chat message using the Chat API
          const result = discourse.createChatMessage({
            channel_name: '#{chat_channel.name}',
            username: '#{user.username}',
            message: params.message
          });

          chain.setCustomRaw("We are done, stopping chaing");

          return {
            success: true,
            message_id: result.message_id,
            url: result.url,
            message: params.message
          };
        }
      JS
        summary: "Notify in chat channel",
        created_by: Discourse.system_user,
      )
    end

    before do
      SiteSetting.chat_enabled = true

      ai_persona.update!(tools: ["custom-#{custom_tool.id}"])

      # Set up automation fields
      automation.fields.create!(
        component: "choices",
        name: "persona",
        metadata: {
          value: ai_persona.id,
        },
        target: "script",
      )

      automation.fields.create!(
        component: "boolean",
        name: "silent_mode",
        metadata: {
          value: true,
        },
        target: "script",
      )
    end

    it "can silently analyze a post and create a chat notification" do
      post = Fabricate(:post, raw: "Please help with my billing issue")

      # Tool response from LLM
      tool_call =
        DiscourseAi::Completions::ToolCall.new(
          name: "chat_notifier",
          parameters: {
            "message" => "Hello world!",
          },
          id: "tool_call_1",
        )

      DiscourseAi::Completions::Llm.with_prepared_responses([tool_call]) do
        automation.running_in_background!
        automation.trigger!({ "post" => post })
      end

      expect(post.topic.reload.posts.count).to eq(1)

      expect(chat_channel.chat_messages.count).to eq(1)
      expect(chat_channel.chat_messages.last.message).to eq("Hello world!")
    end
  end
end
