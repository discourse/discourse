# frozen_string_literal: true

RSpec.describe DiscourseAi::AiBot::Playground do
  subject(:playground) { described_class.new(bot) }

  fab!(:claude_2) do
    Fabricate(
      :llm_model,
      provider: "anthropic",
      url: "https://api.anthropic.com/v1/messages",
      name: "claude-2",
    )
  end
  fab!(:opus_model, :anthropic_model)

  fab!(:bot_user) do
    enable_current_plugin
    toggle_enabled_bots(bots: [claude_2])
    SiteSetting.ai_bot_enabled = true
    claude_2.reload.user
  end

  fab!(:bot) do
    persona =
      AiPersona
        .find(DiscourseAi::Personas::Persona.system_personas[DiscourseAi::Personas::General])
        .class_instance
        .new
    DiscourseAi::Personas::Bot.as(bot_user, persona: persona)
  end

  fab!(:admin) { Fabricate(:admin, refresh_auto_groups: true) }

  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:pm) do
    Fabricate(
      :private_message_topic,
      title: "This is my special PM",
      user: user,
      topic_allowed_users: [
        Fabricate.build(:topic_allowed_user, user: user),
        Fabricate.build(:topic_allowed_user, user: bot_user),
      ],
    )
  end
  fab!(:first_post) do
    Fabricate(:post, topic: pm, user: user, post_number: 1, raw: "This is a reply by the user")
  end
  fab!(:second_post) do
    Fabricate(:post, topic: pm, user: bot_user, post_number: 2, raw: "This is a bot reply")
  end
  fab!(:third_post) do
    Fabricate(
      :post,
      topic: pm,
      user: user,
      post_number: 3,
      raw: "This is a second reply by the user",
    )
  end

  before do
    enable_current_plugin
    SiteSetting.ai_embeddings_enabled = false
  end

  after do
    # we must reset cache on persona cause data can be rolled back
    AiPersona.persona_cache.flush!
  end

  describe "is_bot_user_id?" do
    it "properly detects ALL bots as bot users" do
      persona = Fabricate(:ai_persona, enabled: false)
      persona.create_user!

      expect(DiscourseAi::AiBot::Playground.is_bot_user_id?(persona.user_id)).to eq(true)
    end
  end

  describe "custom tool integration" do
    let!(:custom_tool) do
      AiTool.create!(
        name: "search",
        tool_name: "search",
        summary: "searching for things",
        description: "A test custom tool",
        parameters: [{ name: "query", type: "string", description: "Input for the custom tool" }],
        script:
          "function invoke(params) { return 'Custom tool result: ' + params.query; }; function details() { return 'did stuff'; }",
        created_by: user,
      )
    end

    let!(:ai_persona) { Fabricate(:ai_persona, tools: ["custom-#{custom_tool.id}"]) }
    let(:tool_call) do
      DiscourseAi::Completions::ToolCall.new(
        name: "search",
        id: "666",
        parameters: {
          query: "Can you use the custom tool",
        },
      )
    end

    let(:bot) { DiscourseAi::Personas::Bot.as(bot_user, persona: ai_persona.class_instance.new) }

    let(:playground) { DiscourseAi::AiBot::Playground.new(bot) }

    it "can create uploads from a tool" do
      custom_tool.update!(script: <<~JS)
        let imageBase64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/wcAAgEB/awxUE0AAAAASUVORK5CYII="
        function invoke(params) {
          let image = upload.create("image.png", imageBase64);
          chain.setCustomRaw(`![image](${image.short_url})`);
          return image.id;
        };
      JS

      tool_name = "custom-#{custom_tool.id}"
      ai_persona.update!(tools: [[tool_name, nil, true]], show_thinking: false)

      reply_post = nil
      prompts = nil

      responses = [tool_call]
      DiscourseAi::Completions::Llm.with_prepared_responses(responses) do |_, _, _prompts|
        new_post = Fabricate(:post, raw: "Can you use the custom tool?")
        reply_post = playground.reply_to(new_post)
        prompts = _prompts
      end

      expect(prompts.length).to eq(1)
      upload_id = prompts[0].messages[3][:content].to_i

      upload = Upload.find(upload_id)

      expect(reply_post.raw).to eq("![image](#{upload.short_url})")
    end

    it "can force usage of a tool" do
      tool_name = "custom-#{custom_tool.id}"
      ai_persona.update!(tools: [[tool_name, nil, true]], forced_tool_count: 1)
      responses = [tool_call, ["custom tool did stuff (maybe)"], ["new PM title"]]

      prompts = nil
      reply_post = nil

      private_message = Fabricate(:private_message_topic, user: user)

      DiscourseAi::Completions::Llm.with_prepared_responses(responses) do |_, _, _prompts|
        new_post = Fabricate(:post, raw: "Can you use the custom tool?", topic: private_message)
        reply_post = playground.reply_to(new_post)
        prompts = _prompts
      end

      expect(prompts.length).to eq(3)
      expect(prompts[0].tool_choice).to eq("search")
      expect(prompts[1].tool_choice).to eq(nil)

      ai_persona.update!(forced_tool_count: 1)
      responses = ["no tool call here"]

      DiscourseAi::Completions::Llm.with_prepared_responses(responses) do |_, _, _prompts|
        new_post = Fabricate(:post, raw: "Will you use the custom tool?", topic: reply_post.topic)
        _reply_post = playground.reply_to(new_post)
        prompts = _prompts
      end

      expect(prompts.length).to eq(1)
      expect(prompts[0].tool_choice).to eq(nil)
    end

    it "uses custom tool in conversation" do
      ai_persona.update!(show_thinking: true)
      persona_klass = AiPersona.all_personas.find { |p| p.name == ai_persona.name }
      bot = DiscourseAi::Personas::Bot.as(bot_user, persona: persona_klass.new)
      playground = described_class.new(bot)

      responses = [tool_call, "custom tool did stuff (maybe)"]

      reply_post = nil

      DiscourseAi::Completions::Llm.with_prepared_responses(responses) do
        new_post = Fabricate(:post, raw: "Can you use the custom tool?")
        reply_post = playground.reply_to(new_post)
      end

      expected = <<~TXT.strip
        <details class='ai-thinking'><summary>#{I18n.t("discourse_ai.ai_bot.thinking")}</summary>

        **searching for things**
        did stuff

        </details>

        custom tool did stuff (maybe)
      TXT
      expect(reply_post.raw).to eq(expected)

      custom_prompt = PostCustomPrompt.find_by(post_id: reply_post.id).custom_prompt
      expected_prompt = [
        [
          "{\"arguments\":{\"query\":\"Can you use the custom tool\"}}",
          "666",
          "tool_call",
          "search",
          nil,
          nil,
        ],
        ["\"Custom tool result: Can you use the custom tool\"", "666", "tool", "search"],
        ["custom tool did stuff (maybe)", "claude-2"],
      ]

      expect(custom_prompt).to eq(expected_prompt)

      custom_tool.update!(enabled: false)
      # so we pick up new cache
      persona_klass = AiPersona.all_personas.find { |p| p.name == ai_persona.name }
      bot = DiscourseAi::Personas::Bot.as(bot_user, persona: persona_klass.new)
      playground = DiscourseAi::AiBot::Playground.new(bot)

      responses = ["custom tool did stuff (maybe)", tool_call]

      # lets ensure tool does not run...
      DiscourseAi::Completions::Llm.with_prepared_responses(responses) do |_, _, _prompt|
        new_post = Fabricate(:post, raw: "Can you use the custom tool?")
        reply_post = playground.reply_to(new_post)
      end

      expect(reply_post.raw.strip).to eq("custom tool did stuff (maybe)")
    end
  end

  describe "image support" do
    before do
      Jobs.run_immediately!
      SiteSetting.ai_bot_allowed_groups = "#{Group::AUTO_GROUPS[:trust_level_0]}"
    end

    fab!(:persona) do
      AiPersona.create!(
        name: "Test Persona",
        description: "A test persona",
        allowed_group_ids: [Group::AUTO_GROUPS[:trust_level_0]],
        enabled: true,
        system_prompt: "You are a helpful bot",
        vision_enabled: true,
        vision_max_pixels: 1_000,
        default_llm_id: opus_model.id,
        allow_topic_mentions: true,
      )
    end

    fab!(:upload)

    it "sends images to llm" do
      post = nil

      persona.create_user!

      image = "![image](upload://#{upload.base62_sha1}.jpg)"
      body = "Hey @#{persona.user.username}, can you help me with this image? #{image}"

      prompts = nil
      options = nil
      DiscourseAi::Completions::Llm.with_prepared_responses(
        ["I understood image"],
      ) do |_, _, inner_prompts, inner_options|
        options = inner_options
        post = create_post(user: admin, title: "some new topic I created", raw: body)

        prompts = inner_prompts
      end

      expect(options[0][:feature_name]).to eq("bot")

      content = prompts[0].messages[1][:content]

      expect(content).to include({ upload_id: upload.id })

      expect(prompts[0].max_pixels).to eq(1000)

      post.topic.reload
      last_post = post.topic.posts.order(:post_number).last

      expect(last_post.raw).to eq("I understood image")
    end
  end

  describe "persona with user support" do
    before do
      Jobs.run_immediately!
      SiteSetting.ai_bot_allowed_groups = "#{Group::AUTO_GROUPS[:trust_level_0]}"
    end

    fab!(:persona) do
      persona =
        AiPersona.create!(
          name: "Test Persona",
          description: "A test persona",
          allowed_group_ids: [Group::AUTO_GROUPS[:trust_level_0]],
          enabled: true,
          system_prompt: "You are a helpful bot",
        )

      persona.create_user!
      persona.update!(
        default_llm_id: claude_2.id,
        allow_chat_channel_mentions: true,
        allow_topic_mentions: true,
      )
      persona
    end

    context "with chat channels" do
      fab!(:channel, :chat_channel)

      fab!(:membership) do
        Fabricate(:user_chat_channel_membership, user: user, chat_channel: channel)
      end

      let(:guardian) { Guardian.new(user) }

      before do
        SiteSetting.ai_bot_enabled = true
        SiteSetting.chat_allowed_groups = "#{Group::AUTO_GROUPS[:trust_level_0]}"
        Group.refresh_automatic_groups!
        persona.update!(allow_chat_channel_mentions: true, default_llm_id: opus_model.id)
      end

      it "should behave in a sane way when threading is enabled" do
        channel.update!(threading_enabled: true)

        message =
          ChatSDK::Message.create(
            channel_id: channel.id,
            raw: "thread 1 message 1",
            guardian: guardian,
          )

        message =
          ChatSDK::Message.create(
            channel_id: channel.id,
            raw: "thread 1 message 2",
            in_reply_to_id: message.id,
            guardian: guardian,
          )

        thread = message.thread
        thread.update!(title: "a magic thread")

        message =
          ChatSDK::Message.create(
            channel_id: channel.id,
            raw: "thread 2 message 1",
            guardian: guardian,
          )

        message =
          ChatSDK::Message.create(
            channel_id: channel.id,
            raw: "thread 2 message 2",
            in_reply_to_id: message.id,
            guardian: guardian,
          )

        prompts = nil
        DiscourseAi::Completions::Llm.with_prepared_responses([[" ", "world"]]) do |_, _, _prompts|
          message =
            ChatSDK::Message.create(
              channel_id: channel.id,
              raw: "Hello @#{persona.user.username}",
              guardian: guardian,
            )

          prompts = _prompts
        end

        # don't start a thread cause it will get confusing
        message.reload
        expect(message.thread_id).to be_nil

        prompt = prompts[0]

        content = prompt.messages[1][:content]
        # this is fragile by design, mainly so the example can be ultra clear
        expected = (<<~TEXT).strip
          You are replying inside a Discourse chat channel. Here is a summary of the conversation so far:
          {{{
          #{user.username}: (a magic thread)
          thread 1 message 1
          #{user.username}: thread 2 message 1
          }}}

          Your instructions:
          #{user.username}: Hello
        TEXT

        expect(content.strip).to eq(expected)

        reply = Chat::Message.order(:id).last
        expect(reply.message).to eq("world")
      end

      it "should reply to a mention if properly enabled" do
        prompts = nil

        ChatSDK::Message.create(
          channel_id: channel.id,
          raw: "This is a story about stuff",
          guardian: guardian,
        )

        anthropic_info = { anthropic: { signature: "thinking-signature-123" } }
        thinking_partial =
          DiscourseAi::Completions::Thinking.new(
            message: "I should say hello",
            partial: true,
            provider_info: anthropic_info,
          )

        thinking =
          DiscourseAi::Completions::Thinking.new(
            message: "I should say hello",
            partial: false,
            provider_info: anthropic_info,
          )
        DiscourseAi::Completions::Llm.with_prepared_responses(
          [[thinking_partial, thinking, "wo", "rld"]],
        ) do |_, _, _prompts|
          ChatSDK::Message.create(
            channel_id: channel.id,
            raw: "Hello @#{persona.user.username}",
            guardian: guardian,
          )

          prompts = _prompts
        end

        expect(prompts.length).to eq(1)
        prompt = prompts[0]

        expect(prompt.messages.length).to eq(2)
        expect(prompt.messages[1][:content]).to include("story about stuff")
        expect(prompt.messages[1][:content]).to include("Hello")

        last_message = Chat::Message.where(chat_channel_id: channel.id).order("id desc").first
        expect(last_message.message).to eq("world")
      end

      it "sends error message when credit limit is exceeded" do
        # Create allocation to include in the exception
        seeded_llm = Fabricate(:seeded_model)
        allocation =
          Fabricate(
            :llm_credit_allocation,
            llm_model: seeded_llm,
            daily_credits: 1000,
            daily_used: 1000,
          )

        # Add some chat history first (before stubbing to avoid side effects)
        ChatSDK::Message.create(
          channel_id: channel.id,
          raw: "This is some background conversation",
          guardian: guardian,
        )

        # Stub check_credits! to raise the exception (after background message is created)
        exception =
          LlmCreditAllocation::CreditLimitExceeded.new("Credit limit exceeded", allocation:)
        allow(LlmCreditAllocation).to receive(:check_credits!).and_raise(exception)

        ChatSDK::Message.create(
          channel_id: channel.id,
          raw: "Hello @#{persona.user.username}",
          guardian: guardian,
        )

        last_message = Chat::Message.where(chat_channel_id: channel.id).order("id desc").first

        # Error message has HTML links converted to markdown for chat
        expected_message =
          I18n.t(
            "discourse_ai.llm_credit_allocation.limit_exceeded_user",
            reset_time: allocation.formatted_reset_time,
          ).gsub(%r{<a\s+href=['"]([^'"]+)['"][^>]*>([^<]+)</a>}i, '[\2](\1)')
        expect(last_message.message).to eq(expected_message)
        expect(last_message.user_id).to eq(persona.user_id)
      end

      it "sends admin error message when credit limit is exceeded for admin users" do
        # Stub external URL fetches that may be triggered by message processing
        stub_request(:get, /meta\.discourse\.org/).to_return(
          status: 200,
          body: "",
          headers: {
            "Discourse-No-Onebox" => "1",
          },
        )

        # Create allocation to include in the exception
        seeded_llm = Fabricate(:seeded_model)
        allocation =
          Fabricate(
            :llm_credit_allocation,
            llm_model: seeded_llm,
            daily_credits: 1000,
            daily_used: 1000,
          )

        admin_membership =
          Fabricate(:user_chat_channel_membership, user: admin, chat_channel: channel)
        admin_guardian = Guardian.new(admin)

        # Add some chat history first (before stubbing to avoid side effects)
        ChatSDK::Message.create(
          channel_id: channel.id,
          raw: "This is some background conversation",
          guardian: admin_guardian,
        )

        # Stub check_credits! to raise the exception (after background message is created)
        exception =
          LlmCreditAllocation::CreditLimitExceeded.new("Credit limit exceeded", allocation:)
        allow(LlmCreditAllocation).to receive(:check_credits!).and_raise(exception)

        ChatSDK::Message.create(
          channel_id: channel.id,
          raw: "Hello @#{persona.user.username}",
          guardian: admin_guardian,
        )

        last_message = Chat::Message.where(chat_channel_id: channel.id).order("id desc").first

        # Error message has HTML links converted to markdown for chat
        expected_message =
          I18n.t(
            "discourse_ai.llm_credit_allocation.limit_exceeded_admin",
            reset_time: allocation.formatted_reset_time,
          ).gsub(%r{<a\s+href=['"]([^'"]+)['"][^>]*>([^<]+)</a>}i, '[\2](\1)')
        expect(last_message.message).to eq(expected_message)
        expect(last_message.user_id).to eq(persona.user_id)
      end
    end

    context "with chat dms" do
      fab!(:dm_channel) { Fabricate(:direct_message_channel, users: [user, persona.user]) }

      before do
        SiteSetting.chat_allowed_groups = "#{Group::AUTO_GROUPS[:trust_level_0]}"
        Group.refresh_automatic_groups!
        persona.update!(
          allow_chat_direct_messages: true,
          allow_topic_mentions: false,
          allow_chat_channel_mentions: false,
          default_llm_id: opus_model.id,
        )
        SiteSetting.ai_bot_enabled = true
      end

      let(:guardian) { Guardian.new(user) }

      it "can supply context" do
        post = Fabricate(:post, raw: "this is post content")

        prompts = nil
        message =
          DiscourseAi::Completions::Llm.with_prepared_responses(["World"]) do |_, _, _prompts|
            prompts = _prompts

            ChatSDK::Message.create(
              raw: "Hello",
              channel_id: dm_channel.id,
              context_post_ids: [post.id],
              guardian:,
            )
          end

        expect(prompts[0].messages[1][:content]).to include("this is post content")

        message.reload
        reply = ChatSDK::Thread.messages(thread_id: message.thread_id, guardian: guardian).last
        expect(reply.message).to eq("World")
        expect(message.thread_id).to be_present
      end

      it "can run tools" do
        persona.update!(tools: ["Time"])

        tool_call1 =
          DiscourseAi::Completions::ToolCall.new(
            name: "time",
            id: "time",
            parameters: {
              timezone: "Buenos Aires",
            },
          )

        tool_call2 =
          DiscourseAi::Completions::ToolCall.new(
            name: "time",
            id: "time",
            parameters: {
              timezone: "Sydney",
            },
          )

        responses = [[tool_call1, tool_call2], "The time is 2023-12-14 17:24:00 -0300"]

        message =
          DiscourseAi::Completions::Llm.with_prepared_responses(responses) do
            ChatSDK::Message.create(channel_id: dm_channel.id, raw: "Hello", guardian: guardian)
          end

        message.reload
        expect(message.thread_id).to be_present
        reply = ChatSDK::Thread.messages(thread_id: message.thread_id, guardian: guardian).last

        expect(reply.message).to eq("The time is 2023-12-14 17:24:00 -0300")

        # it also needs to have tool details now set on message
        prompt = ChatMessageCustomPrompt.find_by(message_id: reply.id)

        expect(prompt.custom_prompt.length).to eq(5)

        # TODO in chat I am mixed on including this in the context, but I guess maybe?
        # thinking about this
      end

      it "can reply to a chat message" do
        message =
          DiscourseAi::Completions::Llm.with_prepared_responses(["World"]) do
            ChatSDK::Message.create(channel_id: dm_channel.id, raw: "Hello", guardian: guardian)
          end

        message.reload
        expect(message.thread_id).to be_present

        thread_messages = ChatSDK::Thread.messages(thread_id: message.thread_id, guardian: guardian)
        expect(thread_messages.length).to eq(2)
        expect(thread_messages.last.message).to eq("World")

        # it also needs to include history per config - first feed some history
        persona.update!(enabled: false)
        persona_guardian = Guardian.new(persona.user)

        4.times do |i|
          ChatSDK::Message.create(
            channel_id: dm_channel.id,
            thread_id: message.thread_id,
            raw: "request #{i}",
            guardian: guardian,
          )

          ChatSDK::Message.create(
            channel_id: dm_channel.id,
            thread_id: message.thread_id,
            raw: "response #{i}",
            guardian: persona_guardian,
          )
        end

        persona.update!(max_context_posts: 4, enabled: true)

        prompts = nil
        DiscourseAi::Completions::Llm.with_prepared_responses(
          ["World 2"],
        ) do |_response, _llm, _prompts|
          ChatSDK::Message.create(
            channel_id: dm_channel.id,
            thread_id: message.thread_id,
            raw: "Hello",
            guardian: guardian,
          )
          prompts = _prompts
        end

        expect(prompts.length).to eq(1)

        mapped =
          prompts[0]
            .messages
            .map { |m| "#{m[:type]}: #{m[:content]}" if m[:type] != :system }
            .compact
            .join("\n")
            .strip

        # why?
        # 1. we set context to 4
        # 2. however PromptMessagesBuilder will enforce rules of starting with :user and ending with it
        # so one of the model messages is dropped
        expected = (<<~TEXT).strip
          user: request 3
          model: response 3
          user: Hello
        TEXT

        expect(mapped).to eq(expected)
      end
    end

    it "replies to whispers with a whisper" do
      post = nil
      DiscourseAi::Completions::Llm.with_prepared_responses(["Yes I can"]) do
        post =
          create_post(
            user: admin,
            title: "My public topic",
            raw: "Hey @#{persona.user.username}, can you help me?",
            post_type: Post.types[:whisper],
          )
      end

      post.topic.reload
      last_post = post.topic.posts.order(:post_number).last
      expect(last_post.raw).to eq("Yes I can")
      expect(last_post.user_id).to eq(persona.user_id)
      expect(last_post.post_type).to eq(Post.types[:whisper])
    end

    it "allows mentioning a persona" do
      # we still should be able to mention with no bots
      toggle_enabled_bots(bots: [])

      persona.update!(allow_topic_mentions: true)

      post = nil
      DiscourseAi::Completions::Llm.with_prepared_responses(["Yes I can"]) do
        post =
          create_post(
            user: admin,
            title: "My public topic",
            raw: "Hey @#{persona.user.username}, can you help me?",
          )
      end

      post.topic.reload
      last_post = post.topic.posts.order(:post_number).last
      expect(last_post.raw).to eq("Yes I can")
      expect(last_post.user_id).to eq(persona.user_id)

      persona.update!(allow_topic_mentions: false)

      post =
        create_post(
          title: "My public topic ABC",
          raw: "Hey @#{persona.user.username}, can you help me?",
        )

      expect(post.topic.posts.last.post_number).to eq(1)
    end

    it "allows swapping a llm mid conversation using a mention" do
      SiteSetting.ai_bot_enabled = true

      post = nil
      DiscourseAi::Completions::Llm.with_prepared_responses(
        ["Yes I can", "Magic Title"],
        llm: claude_2,
      ) do
        post =
          create_post(
            title: "I just made a PM",
            raw: "Hey there #{persona.user.username}, can you help me?",
            target_usernames: "#{user.username},#{persona.user.username},#{claude_2.user.username}",
            archetype: Archetype.private_message,
            user: admin,
          )
      end

      # note that this is a string due to custom field shananigans
      post.topic.custom_fields["ai_persona_id"] = persona.id.to_s
      post.topic.save_custom_fields

      llm2 = Fabricate(:llm_model)
      SiteSetting.ai_bot_enabled_llms = llm2.id.to_s
      llm2.toggle_companion_user

      DiscourseAi::Completions::Llm.with_prepared_responses(["Hi from bot two"], llm: llm2) do
        create_post(
          user: admin,
          raw: "hi @#{llm2.user.username.capitalize} how are you",
          topic_id: post.topic_id,
        )
      end

      last_post = post.topic.reload.posts.order("id desc").first
      expect(last_post.raw).to eq("Hi from bot two")
      expect(last_post.user_id).to eq(persona.user_id)

      current_users = last_post.topic.reload.topic_allowed_users.joins(:user).pluck(:username)
      expect(current_users).to include(llm2.user.username)

      # subseqent replies should come from the new llm
      DiscourseAi::Completions::Llm.with_prepared_responses(["Hi from bot two"], llm: llm2) do
        create_post(
          user: admin,
          raw: "just confirming everything switched",
          topic_id: post.topic_id,
        )
      end

      last_post = post.topic.reload.posts.order("id desc").first
      expect(last_post.raw).to eq("Hi from bot two")
      expect(last_post.user_id).to eq(persona.user_id)

      # tether llm, so it can no longer be switched
      persona.update!(force_default_llm: true, default_llm_id: claude_2.id)

      DiscourseAi::Completions::Llm.with_prepared_responses(["Hi from bot one"], llm: claude_2) do
        create_post(
          user: admin,
          raw: "hi @#{llm2.user.username.capitalize} how are you",
          topic_id: post.topic_id,
        )
      end

      last_post = post.topic.reload.posts.order("id desc").first
      expect(last_post.raw).to eq("Hi from bot one")
      expect(last_post.user_id).to eq(persona.user_id)
    end

    it "allows PMing a persona even when no particular bots are enabled" do
      SiteSetting.ai_bot_enabled = true
      toggle_enabled_bots(bots: [])
      post = nil

      DiscourseAi::Completions::Llm.with_prepared_responses(
        ["Yes I can", "Magic Title"],
        llm: claude_2,
      ) do
        post =
          create_post(
            title: "I just made a PM",
            raw: "Hey there #{persona.user.username}, can you help me?",
            target_usernames: "#{user.username},#{persona.user.username}",
            archetype: Archetype.private_message,
            user: admin,
          )
      end

      last_post = post.topic.posts.order(:post_number).last
      expect(last_post.raw).to eq("Yes I can")
      expect(last_post.user_id).to eq(persona.user_id)

      last_post.topic.reload
      expect(last_post.topic.allowed_users.pluck(:user_id)).to include(persona.user_id)

      expect(last_post.topic.participant_count).to eq(2)

      # ensure it can be disabled
      persona.update!(allow_personal_messages: false)

      post =
        create_post(
          raw: "Hey there #{persona.user.username}, can you help me please",
          topic_id: post.topic.id,
          user: admin,
        )

      expect(post.post_number).to eq(3)
    end

    it "can tether a persona unconditionally to an llm" do
      gpt_35_turbo = Fabricate(:llm_model, name: "gpt-3.5-turbo")

      # If you start a PM with GPT 3.5 bot, replies should come from it, not from Claude
      SiteSetting.ai_bot_enabled = true
      toggle_enabled_bots(bots: [gpt_35_turbo, claude_2])

      post = nil
      persona.update!(force_default_llm: true, default_llm_id: gpt_35_turbo.id)

      DiscourseAi::Completions::Llm.with_prepared_responses(
        ["Yes I can", "Magic Title"],
        llm: gpt_35_turbo,
      ) do
        post =
          create_post(
            title: "I just made a PM",
            raw: "hello world",
            target_usernames: "#{user.username},#{claude_2.user.username}",
            archetype: Archetype.private_message,
            user: admin,
            custom_fields: {
              "ai_persona_id" => persona.id,
            },
          )
      end

      last_post = post.topic.posts.order(:post_number).last
      expect(last_post.raw).to eq("Yes I can")
      expect(last_post.user_id).to eq(persona.user_id)

      expect(last_post.custom_fields[DiscourseAi::AiBot::POST_AI_LLM_NAME_FIELD]).to eq(
        gpt_35_turbo.display_name,
      )
    end

    it "picks the correct llm for persona in PMs" do
      gpt_35_turbo = Fabricate(:llm_model, name: "gpt-3.5-turbo")

      # If you start a PM with GPT 3.5 bot, replies should come from it, not from Claude
      SiteSetting.ai_bot_enabled = true
      toggle_enabled_bots(bots: [gpt_35_turbo, claude_2])

      post = nil
      gpt3_5_bot_user = gpt_35_turbo.reload.user
      messages = nil

      DiscourseAi::Completions::Llm.with_prepared_responses(
        ["Yes I can", "Magic Title"],
        llm: gpt_35_turbo,
      ) do
        messages =
          MessageBus.track_publish do
            post =
              create_post(
                title: "I just made a PM",
                raw: "Hey @#{persona.user.username}, can you help me?",
                target_usernames: "#{user.username},#{gpt3_5_bot_user.username}",
                archetype: Archetype.private_message,
                user: admin,
              )
          end
      end

      title_update_message =
        messages.find { |m| m.channel == "/discourse-ai/ai-bot/topic/#{post.topic.id}" }

      expect(title_update_message.data).to eq({ title: "Magic Title" })
      last_post = post.topic.posts.order(:post_number).last
      expect(last_post.raw).to eq("Yes I can")
      expect(last_post.user_id).to eq(persona.user_id)

      last_post.topic.reload
      expect(last_post.topic.allowed_users.pluck(:user_id)).to include(persona.user_id)

      # does not reply if replying directly to a user
      # nothing is mocked, so this would result in HTTP error
      # if we were going to reply
      create_post(
        raw: "Please ignore this bot, I am replying to a user",
        topic: post.topic,
        user: admin,
        reply_to_post_number: post.post_number,
      )

      # replies as correct persona if replying direct to persona
      DiscourseAi::Completions::Llm.with_prepared_responses(["Another reply"], llm: gpt_35_turbo) do
        create_post(
          raw: "Please ignore this bot, I am replying to a user",
          topic: post.topic,
          user: admin,
          reply_to_post_number: last_post.post_number,
        )
      end

      last_post = post.topic.posts.order(:post_number).last
      expect(last_post.raw).to eq("Another reply")
      expect(last_post.user_id).to eq(persona.user_id)
    end
  end

  describe "#title_playground" do
    let(:expected_response) { "This is a suggested title" }

    before { SiteSetting.min_personal_message_post_length = 5 }

    it "updates the title using bot suggestions" do
      DiscourseAi::Completions::Llm.with_prepared_responses([expected_response]) do
        playground.title_playground(third_post, user)
        expect(pm.reload.title).to eq(expected_response)
      end
    end
  end

  describe "#reply_to" do
    it "preserves thinking context between replies and correctly renders" do
      thinking_progress =
        DiscourseAi::Completions::Thinking.new(message: "I should say hello", partial: true)
      anthropic_info = { anthropic: { signature: "thinking-signature-123" } }
      thinking =
        DiscourseAi::Completions::Thinking.new(
          message: "I should say hello",
          partial: false,
          provider_info: anthropic_info,
        )

      thinking_redacted =
        DiscourseAi::Completions::Thinking.new(
          message: nil,
          partial: false,
          provider_info: {
            anthropic: {
              redacted_signature: "thinking-redacted-signature-123",
            },
          },
        )

      first_responses = [[thinking_progress, thinking, thinking_redacted, "Hello Sam"]]

      DiscourseAi::Completions::Llm.with_prepared_responses(first_responses) do
        playground.reply_to(third_post)
      end

      new_post = third_post.topic.reload.posts.order(:post_number).last
      # confirm message is there
      expect(new_post.raw).to include("Hello Sam")
      # confirm thinking is there
      expect(new_post.raw).to include("I should say hello")

      post = Fabricate(:post, topic: third_post.topic, user: user, raw: "Say Cat")

      prompt_detail = nil
      # Capture the prompt to verify thinking context was included
      DiscourseAi::Completions::Llm.with_prepared_responses(["Cat"]) do |_, _, prompts|
        playground.reply_to(post)
        prompt_detail = prompts.first
      end

      last_messages = prompt_detail.messages.last(2)

      expect(last_messages).to eq(
        [
          {
            type: :model,
            content: "Hello Sam",
            thinking: "I should say hello",
            thinking_provider_info: {
              anthropic: {
                signature: "thinking-signature-123",
                redacted_signature: "thinking-redacted-signature-123",
              },
            },
          },
          { type: :user, content: "Say Cat", id: user.username },
        ],
      )
    end

    it "streams the bot reply through MB and create a new post in the PM with a cooked responses" do
      expected_bot_response =
        "Hello this is a bot and what you just said is an interesting question"

      DiscourseAi::Completions::Llm.with_prepared_responses([expected_bot_response]) do
        messages =
          MessageBus.track_publish("discourse-ai/ai-bot/topic/#{pm.id}") do
            playground.reply_to(third_post)
          end

        reply = pm.reload.posts.last

        noop_signal = messages.pop
        expect(noop_signal.data[:noop]).to eq(true)

        done_signal = messages.pop
        expect(done_signal.data[:done]).to eq(true)
        expect(done_signal.data[:cooked]).to eq(reply.cooked)

        expect(messages.first.data[:raw]).to eq("")

        expect(reply.cooked).to eq(PrettyText.cook(expected_bot_response))

        messages[1..-1].each do |m|
          expect(expected_bot_response.start_with?(m.data[:raw])).to eq(true)
        end
      end
    end

    it "supports multiple function calls" do
      tool_call1 =
        DiscourseAi::Completions::ToolCall.new(
          name: "search",
          id: "search",
          parameters: {
            search_query: "testing various things",
          },
        )

      tool_call2 =
        DiscourseAi::Completions::ToolCall.new(
          name: "search",
          id: "search",
          parameters: {
            search_query: "another search",
          },
        )

      response2 = "I found stuff"

      DiscourseAi::Completions::Llm.with_prepared_responses(
        [[tool_call1, tool_call2], response2],
      ) { playground.reply_to(third_post) }

      last_post = third_post.topic.reload.posts.order(:post_number).last

      expect(last_post.raw).to include("testing various things")
      expect(last_post.raw).to include("another search")
      expect(last_post.raw).to include("I found stuff")
    end

    it "supports disabling thinking" do
      persona = Fabricate(:ai_persona, show_thinking: false, tools: ["Search"])
      bot = DiscourseAi::Personas::Bot.as(bot_user, persona: persona.class_instance.new)
      playground = described_class.new(bot)

      response1 =
        DiscourseAi::Completions::ToolCall.new(
          name: "search",
          id: "search",
          parameters: {
            search_query: "testing various things",
          },
        )

      response2 = "I found stuff"

      DiscourseAi::Completions::Llm.with_prepared_responses([response1, response2]) do
        playground.reply_to(third_post)
      end

      last_post = third_post.topic.reload.posts.order(:post_number).last

      expect(last_post.raw).to eq("I found stuff")
    end

    it "does not include placeholders in conversation context but includes all completions" do
      response1 =
        DiscourseAi::Completions::ToolCall.new(
          name: "search",
          id: "search",
          parameters: {
            search_query: "testing various things",
          },
        )

      response2 = "I found some really amazing stuff!"

      DiscourseAi::Completions::Llm.with_prepared_responses([response1, response2]) do
        playground.reply_to(third_post)
      end

      last_post = third_post.topic.reload.posts.order(:post_number).last
      custom_prompt = PostCustomPrompt.where(post_id: last_post.id).first.custom_prompt

      expect(custom_prompt.length).to eq(3)
      expect(custom_prompt.to_s).not_to include("<details>")
      expect(custom_prompt.last.first).to eq(response2)
      expect(custom_prompt.last.last).to eq(bot_user.username)
    end

    it "sends credit limit error message when credit limit is exceeded in PM" do
      seeded_llm = Fabricate(:seeded_model)
      allocation =
        Fabricate(
          :llm_credit_allocation,
          llm_model: seeded_llm,
          daily_credits: 1000,
          daily_used: 1000,
        )

      exception = LlmCreditAllocation::CreditLimitExceeded.new("Credit limit exceeded", allocation:)
      allow(LlmCreditAllocation).to receive(:check_credits!).and_raise(exception)

      expect { playground.reply_to(third_post) }.not_to raise_error

      last_post = pm.reload.posts.order(:post_number).last

      expected_message =
        I18n.t(
          "discourse_ai.llm_credit_allocation.limit_exceeded_user",
          reset_time: allocation.formatted_reset_time,
        )
      expect(last_post.raw).to include(expected_message)
      expect(last_post.user_id).to eq(bot_user.id)
    end

    it "sends admin credit limit error message when credit limit is exceeded for admin users" do
      seeded_llm = Fabricate(:seeded_model)
      allocation =
        Fabricate(
          :llm_credit_allocation,
          llm_model: seeded_llm,
          daily_credits: 1000,
          daily_used: 1000,
        )

      # Add admin to existing PM
      pm.topic_allowed_users.create!(user_id: admin.id)

      admin_post =
        Fabricate(:post, topic: pm, user: admin, post_number: 4, raw: "Hello bot from admin")

      exception = LlmCreditAllocation::CreditLimitExceeded.new("Credit limit exceeded", allocation:)
      allow(LlmCreditAllocation).to receive(:check_credits!).and_raise(exception)

      expect { playground.reply_to(admin_post) }.not_to raise_error

      last_post = pm.reload.posts.order(:post_number).last

      expected_message =
        I18n.t(
          "discourse_ai.llm_credit_allocation.limit_exceeded_admin",
          reset_time: allocation.formatted_reset_time,
        )
      expect(last_post.raw).to include(expected_message)
      expect(last_post.user_id).to eq(bot_user.id)
    end
  end

  describe "#canceling a completions" do
    after { DiscourseAi::AiBot::PostStreamer.on_callback = nil }

    it "should be able to cancel a completion halfway through" do
      body = (<<~STRING).strip
      event: message_start
      data: {"type": "message_start", "message": {"id": "msg_1nZdL29xx5MUA1yADyHTEsnR8uuvGzszyY", "type": "message", "role": "assistant", "content": [], "model": "claude-3-opus-20240229", "stop_reason": null, "stop_sequence": null, "usage": {"input_tokens": 25, "output_tokens": 1}}}

      event: content_block_start
      data: {"type": "content_block_start", "index":0, "content_block": {"type": "text", "text": ""}}

      event: ping
      data: {"type": "ping"}

      |event: content_block_delta
      data: {"type": "content_block_delta", "index": 0, "delta": {"type": "text_delta", "text": "Hello"}}

      |event: content_block_delta
      data: {"type": "content_block_delta", "index": 0, "delta": {"type": "text_delta", "text": "1"}}

      |event: content_block_delta
      data: {"type": "content_block_delta", "index": 0, "delta": {"type": "text_delta", "text": "2"}}

      |event: content_block_delta
      data: {"type": "content_block_delta", "index": 0, "delta": {"type": "text_delta", "text": "3"}}

      event: content_block_stop
      data: {"type": "content_block_stop", "index": 0}

      event: message_delta
      data: {"type": "message_delta", "delta": {"stop_reason": "end_turn", "stop_sequence":null, "usage":{"output_tokens": 15}}}

      event: message_stop
      data: {"type": "message_stop"}
    STRING

      split = body.split("|")

      cancel_manager = DiscourseAi::Completions::CancelManager.new

      count = 0
      DiscourseAi::AiBot::PostStreamer.on_callback =
        proc do |callback|
          count += 1
          cancel_manager.cancel! if count == 2
          raise "this should not happen" if count > 2
        end

      require_relative("../../completions/endpoints/endpoint_compliance")
      EndpointMock.with_chunk_array_support do
        stub_request(:post, "https://api.anthropic.com/v1/messages").to_return(
          status: 200,
          body: split,
        )
        # we are going to need to use real data here cause we want to trigger the
        # base endpoint to cancel part way through
        playground.reply_to(third_post, cancel_manager: cancel_manager)
      end

      last_post = third_post.topic.posts.order(:id).last

      # not Hello123, we cancelled at 1
      expect(last_post.raw).to eq("Hello1")
    end
  end

  describe "#available_bot_usernames" do
    it "includes persona users" do
      persona = Fabricate(:ai_persona)
      persona.create_user!

      expect(playground.available_bot_usernames).to include(persona.user.username)
    end
  end

  describe "custom tool context injection" do
    let!(:custom_tool) do
      AiTool.create!(
        name: "context_tool",
        tool_name: "context_tool",
        summary: "tool with custom context",
        description: "A test custom tool that injects context",
        parameters: [{ name: "query", type: "string", description: "Input for the custom tool" }],
        script: <<~JS,
          function invoke(params) {
            return 'Custom tool result: ' + params.query;
          }

          function customContext() {
            return "This is additional context from the tool";
          }

          function details() {
            return 'executed with custom context';
          }
        JS
        created_by: user,
      )
    end

    let!(:ai_persona) { Fabricate(:ai_persona, tools: ["custom-#{custom_tool.id}"]) }
    let(:bot) { DiscourseAi::Personas::Bot.as(bot_user, persona: ai_persona.class_instance.new) }
    let(:playground) { DiscourseAi::AiBot::Playground.new(bot) }

    it "injects custom context into the prompt" do
      prompts = nil
      response = "I received the additional context"

      DiscourseAi::Completions::Llm.with_prepared_responses([response]) do |_, _, _prompts|
        new_post = Fabricate(:post, raw: "Can you use the custom context tool?")
        playground.reply_to(new_post)
        prompts = _prompts
      end

      # The first prompt should have the custom context prepended to the user message
      user_message = prompts[0].messages.last
      expect(user_message[:content]).to include("This is additional context from the tool")
      expect(user_message[:content]).to include("Can you use the custom context tool?")
    end
  end

  it "does not raise 'can't modify frozen attributes' when retrying a reply with thinking" do
    thinking_progress =
      DiscourseAi::Completions::Thinking.new(message: "I should say hello", partial: true)
    anthropic_info = { anthropic: { signature: "thinking-signature-123" } }
    thinking =
      DiscourseAi::Completions::Thinking.new(
        message: "I should say hello",
        partial: false,
        provider_info: anthropic_info,
      )

    # 1. First reply that creates thinking context
    first_responses = [[thinking_progress, thinking, "Hello Sam"]]

    reply_post = nil
    DiscourseAi::Completions::Llm.with_prepared_responses(first_responses) do
      reply_post = playground.reply_to(third_post)
    end

    expect(PostCustomPrompt.exists?(post_id: reply_post.id)).to eq(true)

    # 2. Retry the same reply (this is what triggers the bug)
    second_responses = [[thinking_progress, thinking, "Hello again Sam"]]

    expect {
      DiscourseAi::Completions::Llm.with_prepared_responses(second_responses) do
        playground.reply_to(third_post, existing_reply_post: reply_post)
      end
    }.not_to raise_error
  end
end
