# frozen_string_literal: true

return if !defined?(DiscourseAutomation)

describe DiscourseAi::Automation::LlmTriage do
  fab!(:category)
  fab!(:reply_user, :user)
  fab!(:personal_message, :private_message_topic)
  let(:canned_reply_text) { "Hello, this is a reply" }

  let(:automation) { Fabricate(:automation, script: "llm_triage", enabled: true) }

  fab!(:llm_model)
  fab!(:ai_persona)

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

    SiteSetting.tagging_enabled = true

    ai_persona.update!(default_llm: llm_model)

    add_automation_field("triage_persona", ai_persona.id)
    add_automation_field("search_for_text", "bad")
    add_automation_field("category", category.id, type: "category")
    add_automation_field("tags", %w[aaa bbb], type: "tags")
    add_automation_field("hide_topic", true, type: "boolean")
    add_automation_field("flag_post", true, type: "boolean")
    add_automation_field("canned_reply", canned_reply_text)
    add_automation_field("canned_reply_user", reply_user.username, type: "user")
    add_automation_field("max_post_tokens", 100)
  end

  it "can trigger via automation" do
    post = Fabricate(:post, raw: "hello " * 5000)

    chunks = <<~RESPONSE
    data: {"id":"chatcmpl-B2VwlY6KzSDtHvg8pN1VAfRhhLFgn","object":"chat.completion.chunk","created":1739939159,"model": "gpt-3.5-turbo-0301","service_tier":"default","system_fingerprint":"fp_ef58bd3122","choices":[{"index":0,"delta":{"role":"assistant","content":"","refusal":null},"finish_reason":null}],"usage":null}

    data: {"id":"chatcmpl-B2VwlY6KzSDtHvg8pN1VAfRhhLFgn","object":"chat.completion.chunk","created":1739939159,"model": "gpt-3.5-turbo-0301","service_tier":"default","system_fingerprint":"fp_ef58bd3122","choices":[{"index":0,"delta":{"content":"bad"},"finish_reason":null}],"usage":null}

    data: [DONE]
    RESPONSE

    WebMock.stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
      status: 200,
      body: chunks,
    )

    automation.running_in_background!
    automation.trigger!({ "post" => post })

    topic = post.topic.reload
    expect(topic.category_id).to eq(category.id)
    expect(topic.tags.pluck(:name)).to contain_exactly("aaa", "bbb")
    expect(topic.visible).to eq(false)
    reply = topic.posts.order(:post_number).last
    expect(reply.raw).to eq(canned_reply_text)
    expect(reply.user.id).to eq(reply_user.id)

    ai_log = AiApiAuditLog.order("id desc").first
    expect(ai_log.feature_name).to eq("llm_triage")
    expect(ai_log.feature_context).to eq(
      { "automation_id" => automation.id, "automation_name" => automation.name },
    )

    count = ai_log.raw_request_payload.scan("hello").size
    # we could use the exact count here but it can get fragile
    # as we change tokenizers, this will give us reasonable confidence
    expect(count).to be <= (100)
    expect(count).to be > (50)
  end

  it "does not triage PMs by default" do
    post = Fabricate(:post, topic: personal_message)
    automation.running_in_background!
    automation.trigger!({ "post" => post })

    # nothing should happen, no classification, its a PM
  end

  it "will triage PMs if automation allows it" do
    # needs to be admin or it will not be able to just step in to
    # PM
    reply_user.update!(admin: true)
    add_automation_field("include_personal_messages", true, type: :boolean)
    ai_persona.update!(temperature: 0.2)
    add_automation_field("max_output_tokens", "700")
    post = Fabricate(:post, topic: personal_message)

    prompt_options = nil
    DiscourseAi::Completions::Llm.with_prepared_responses(
      ["bad"],
    ) do |_resp, _llm, _prompts, _prompt_options|
      automation.running_in_background!
      automation.trigger!({ "post" => post })
      prompt_options = _prompt_options.first
    end

    expect(prompt_options[:temperature]).to eq(0.2)
    expect(prompt_options[:max_tokens]).to eq(700)

    last_post = post.topic.reload.posts.order(:post_number).last
    expect(last_post.raw).to eq(canned_reply_text)
  end

  it "does not reply to the canned_reply_user" do
    post = Fabricate(:post, user: reply_user)

    DiscourseAi::Completions::Llm.with_prepared_responses(["bad"]) do
      automation.running_in_background!
      automation.trigger!({ "post" => post })
    end

    last_post = post.topic.reload.posts.order(:post_number).last
    expect(last_post.raw).to eq post.raw
  end

  it "can respond using an AI persona when configured" do
    bot_user = Fabricate(:user, username: "ai_assistant")
    ai_persona =
      Fabricate(
        :ai_persona,
        name: "Help Bot",
        description: "AI assistant for forum help",
        system_prompt: "You are a helpful forum assistant",
        default_llm: llm_model,
        user_id: bot_user.id,
      )

    # Configure the automation to use the persona instead of canned reply
    add_automation_field("canned_reply", nil, type: "message") # Clear canned reply
    add_automation_field("reply_persona", ai_persona.id, type: "choices")
    add_automation_field("whisper", true, type: "boolean")

    post = Fabricate(:post, raw: "I need help with a problem")

    ai_response = "I'll help you with your problem!"

    # Set up the test to provide both the triage and the persona responses
    DiscourseAi::Completions::Llm.with_prepared_responses(["bad", ai_response]) do
      automation.running_in_background!
      automation.trigger!({ "post" => post })
    end

    # Verify the response was created
    topic = post.topic.reload
    last_post = topic.posts.order(:post_number).last

    # Verify the AI persona's user created the post
    expect(last_post.user_id).to eq(bot_user.id)

    # Verify the content matches the AI response
    expect(last_post.raw).to eq(ai_response)

    # Verify it's a whisper post (since we set whisper: true)
    expect(last_post.post_type).to eq(Post.types[:whisper])
  end

  it "does not create replies when the action is edit" do
    # Set up bot user and persona
    bot_user = Fabricate(:user, username: "helper_bot")
    ai_persona =
      Fabricate(
        :ai_persona,
        name: "Edit Helper",
        description: "AI assistant for editing",
        system_prompt: "You help with editing",
        default_llm: llm_model,
        user_id: bot_user.id,
      )

    # Configure the automation with both reply methods
    add_automation_field("canned_reply", "This is a canned reply", type: "message")
    add_automation_field("reply_persona", ai_persona.id, type: "choices")

    # Create a post and capture its topic
    post = Fabricate(:post, raw: "This needs to be evaluated")
    topic = post.topic

    # Get initial post count
    initial_post_count = topic.posts.count

    # Run automation with action: :edit and a matching response
    DiscourseAi::Completions::Llm.with_prepared_responses(["bad"]) do
      automation.running_in_background!
      automation.trigger!({ "post" => post, "action" => :edit })
    end

    # Topic should be updated (if configured) but no new posts
    topic.reload
    expect(topic.posts.count).to eq(initial_post_count)

    # Verify no replies were created
    last_post = topic.posts.order(:post_number).last
    expect(last_post.id).to eq(post.id)
  end
end
