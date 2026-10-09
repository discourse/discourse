# frozen_string_literal: true

RSpec.describe DiscourseAi::Completions::HistorySnapshot do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:other_user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:bot_user, :user)
  fab!(:source) { Fabricate(:private_message_post, user: user, recipient: bot_user) }

  before { enable_current_plugin }

  def post_snapshot(post, reader = user)
    described_class.post(post, guardian: reader.guardian, bot_usernames: [bot_user.username])
  end

  def checkpoint(snapshot)
    entries = [
      ["<compressed_context>Cached original evidence</compressed_context>", nil, "user"],
      [DiscourseAi::Completions::PromptMessagesBuilder::COMPRESSED_CONTEXT_ACK, nil, "model"],
      ["Visible answer", bot_user.username],
    ]
    snapshot.stamp!(entries)
    entries
  end

  def post_messages(latest, reader = user)
    DiscourseAi::Completions::PromptMessagesBuilder.messages_from_post(
      latest,
      guardian: reader.guardian,
      max_posts: 2,
      bot_usernames: [bot_user.username],
      history_snapshot: post_snapshot(latest, reader),
    )
  end

  def chat_messages(latest, channel)
    snapshot = described_class.chat(latest, guardian: user.guardian, bot_user_ids: [bot_user.id])
    DiscourseAi::Completions::PromptMessagesBuilder.messages_from_chat(
      latest,
      channel: channel,
      context_post_ids: nil,
      max_messages: 2,
      bot_user_ids: [bot_user.id],
      history_snapshot: snapshot,
    )
  end

  it "retains the first eligible bot answer after the initial PM user post is deleted" do
    reply = Fabricate(:post, topic: source.topic, user: bot_user, raw: "Retained bot evidence")
    latest = Fabricate(:post, topic: source.topic, user: user, raw: "Continue the conversation")
    source.trash!

    messages = post_messages(latest)
    expect(messages.first[:type]).to eq(:user)
    expect(messages.to_s).to include(reply.raw, latest.raw)
    expect(messages.to_s).not_to include(source.raw)
    expect { DiscourseAi::Completions::Prompt.new("System", messages: messages) }.not_to raise_error
  end

  it "retains the first visible PM bot answer when another reader cannot see the original hidden post" do
    source.topic.topic_allowed_users.create!(user: other_user)
    reply = Fabricate(:post, topic: source.topic, user: bot_user, raw: "First visible bot evidence")
    latest = Fabricate(:post, topic: source.topic, user: other_user)
    source.update!(hidden: true)

    messages = post_messages(latest, other_user)
    expect(messages.first[:type]).to eq(:user)
    expect(messages.to_s).to include(reply.raw, latest.raw)
    expect(messages.to_s).not_to include(source.raw)
    expect { DiscourseAi::Completions::Prompt.new("System", messages: messages) }.not_to raise_error
  end

  it "retains bot-started public threads and falls back after their original is deleted" do
    channel = Fabricate(:category_channel, threading_enabled: true)
    original =
      Fabricate(:chat_message, chat_channel: channel, user: bot_user, message: "Bot original")
    thread = Fabricate(:chat_thread, channel: channel, original_message: original)
    original.update!(thread: thread)
    reply =
      Fabricate(
        :chat_message,
        chat_channel: channel,
        thread: thread,
        user: bot_user,
        message: "Retained thread evidence",
      )
    latest =
      Fabricate(
        :chat_message,
        chat_channel: channel,
        thread: thread,
        user: user,
        message: "Continue thread",
      )

    messages = chat_messages(latest, channel)
    expect(messages.first[:type]).to eq(:user)
    expect(messages.to_s).to include(original.message, reply.message, latest.message)
    expect { DiscourseAi::Completions::Prompt.new("System", messages: messages) }.not_to raise_error

    original.trash!
    messages = chat_messages(latest, channel)
    expect(messages.to_s).to include(reply.message, latest.message)
    expect(messages.to_s).not_to include(original.message)
    expect { DiscourseAi::Completions::Prompt.new("System", messages: messages) }.not_to raise_error

    channel.update!(threading_enabled: false)
    expect { chat_messages(latest, channel) }.to raise_error(
      DiscourseAi::Completions::ContextPreparation::Error,
      /history_changed/,
    )
    channel.update!(
      threading_enabled: true,
      chatable: Fabricate(:private_category, group: Group[:staff]),
    )
    expect { chat_messages(latest, channel) }.to raise_error(
      DiscourseAi::Completions::ContextPreparation::Error,
      /history_changed/,
    )
  end

  it "retains a model-started DM after its first human message is deleted" do
    channel = Fabricate(:direct_message_channel, users: [user, bot_user])
    original = Fabricate(:chat_message, chat_channel: channel, user: user)
    reply =
      Fabricate(
        :chat_message,
        chat_channel: channel,
        user: bot_user,
        message: "Retained DM evidence",
      )
    latest = Fabricate(:chat_message, chat_channel: channel, user: user)
    original.trash!

    messages = chat_messages(latest, channel)
    expect(messages.first[:type]).to eq(:user)
    expect(messages.to_s).to include(reply.message, latest.message)
    expect(messages.to_s).not_to include(original.message)
    expect { DiscourseAi::Completions::Prompt.new("System", messages: messages) }.not_to raise_error
  end

  it "reuses a checkpoint for a transcript larger than two windows after access and participant expansion" do
    SiteSetting.max_post_length = 150_000
    original = "Long original evidence " * 800
    source.update!(raw: original)
    entries = checkpoint(post_snapshot(source))
    reply = Fabricate(:post, topic: source.topic, user: bot_user, raw: "Visible answer")
    PostCustomPrompt.create!(post_id: reply.id, custom_prompt: entries)
    second_source = Fabricate(:post, topic: source.topic, user: user, raw: original)
    entries = checkpoint(post_snapshot(second_source))
    second_reply =
      Fabricate(:post, topic: source.topic, user: bot_user, raw: "Second checkpoint answer")
    PostCustomPrompt.create!(post_id: second_reply.id, custom_prompt: entries)
    latest = Fabricate(:post, topic: source.topic, user: user, raw: "Continue from the checkpoint")
    group = Fabricate(:group)
    group.add(user)
    user.update!(trust_level: 2)
    source.topic.topic_allowed_users.create!(user: other_user)
    model = Fabricate(:fake_model, max_prompt_tokens: 1000, max_output_tokens: 200)
    llm = DiscourseAi::Completions::Llm.proxy(model)
    expect(llm.tokenizer.size(original)).to be > 2 * model.max_prompt_tokens
    messages = post_messages(latest)
    prompt = DiscourseAi::Completions::Prompt.new("System", messages: messages)

    DiscourseAi::Completions::Llm.with_prepared_responses([]) do |canned|
      expect(
        DiscourseAi::Completions::ContextPreparation.new(llm).prepare!(prompt, user: user),
      ).to eq(:not_needed)
      expect(canned.completions).to eq(0)
    end
    expect(messages.to_s).to include(entries.first.first, latest.raw)
    expect(messages.to_s).not_to include(original)
  end

  it "replays PM sources between checkpoint coverage and its delayed carrier" do
    entries = checkpoint(post_snapshot(source))
    gap =
      Fabricate(:post, topic: source.topic, user: user, raw: "Interleaved unsummarized PM evidence")
    carrier = Fabricate(:post, topic: source.topic, user: bot_user, raw: "Delayed reply")
    entries.last[0] = carrier.raw
    PostCustomPrompt.create!(post_id: carrier.id, custom_prompt: entries)
    latest = Fabricate(:post, topic: source.topic, user: user, raw: "Next request")

    text = post_messages(latest).to_s
    expect(text).to include(entries.first.first, gap.raw, carrier.raw, latest.raw)
    expect(text.index(gap.raw)).to be < text.index(carrier.raw)
    expect(text.index(carrier.raw)).to be < text.index(latest.raw)
    expect(
      PostCustomPrompt.find_by!(post_id: carrier.id).custom_prompt.first[6]["source_id"],
    ).to eq(source.id)
  end

  it "replays DM sources between checkpoint coverage and its delayed carrier" do
    channel = Fabricate(:direct_message_channel, users: [user, bot_user])
    original = Fabricate(:chat_message, chat_channel: channel, user: user)
    snapshot = described_class.chat(original, guardian: user.guardian, bot_user_ids: [bot_user.id])
    entries = checkpoint(snapshot)
    gap =
      Fabricate(
        :chat_message,
        chat_channel: channel,
        user: user,
        message: "Interleaved unsummarized chat evidence",
      )
    carrier =
      Fabricate(:chat_message, chat_channel: channel, user: bot_user, message: "Delayed chat reply")
    entries.last[0] = carrier.message
    ChatMessageCustomPrompt.create!(message_id: carrier.id, custom_prompt: entries)
    latest =
      Fabricate(:chat_message, chat_channel: channel, user: user, message: "Next chat request")

    text = chat_messages(latest, channel).to_s
    expect(text).to include(entries.first.first, gap.message, carrier.message, latest.message)
    expect(text.index(gap.message)).to be < text.index(carrier.message)
  end

  it "loads interleaved PM evidence across recovery pages before the delayed carrier" do
    builder = DiscourseAi::Completions::PromptMessagesBuilder
    stub_const(builder, :MAX_CONTEXT_MESSAGES, 3) do
      entries = checkpoint(post_snapshot(source))
      now = Time.current
      rows =
        (builder::MAX_CONTEXT_MESSAGES + 1).times.map do |index|
          {
            topic_id: source.topic_id,
            user_id: user.id,
            post_number: index + 2,
            raw: "Interleaved page evidence #{index}",
            cooked: "Interleaved page evidence #{index}",
            post_type: Post.types[:regular],
            created_at: now,
            updated_at: now,
            last_version_at: now,
          }
        end
      Post.insert_all!(rows)
      carrier =
        Fabricate(
          :post,
          topic: source.topic,
          user: bot_user,
          post_number: rows.length + 2,
          raw: "Delayed paginated reply",
        )
      entries.last[0] = carrier.raw
      PostCustomPrompt.create!(post_id: carrier.id, custom_prompt: entries)
      latest =
        Fabricate(
          :post,
          topic: source.topic,
          user: user,
          post_number: rows.length + 3,
          raw: "Continue after delayed reply",
        )

      text = post_messages(latest).to_s
      expect(text).to include(
        entries.first[0],
        *rows.map { |row| row[:raw] },
        carrier.raw,
        latest.raw,
      )
    end
  end

  it "retains a reader-scoped DM checkpoint after another participant joins" do
    channel = Fabricate(:direct_message_channel, users: [user, bot_user])
    original = Fabricate(:chat_message, chat_channel: channel, user: user)
    snapshot = described_class.chat(original, guardian: user.guardian, bot_user_ids: [bot_user.id])
    entries = checkpoint(snapshot)
    carrier = Fabricate(:chat_message, chat_channel: channel, user: bot_user)
    ChatMessageCustomPrompt.create!(message_id: carrier.id, custom_prompt: entries)
    channel.chatable.users << other_user
    latest = Fabricate(:chat_message, chat_channel: channel, user: user)

    expect(chat_messages(latest, channel).to_s).to include(entries.first[0])
  end

  it "rejects an earlier coverage boundary if provenance filtering removes the loaded checkpoint" do
    older_entries = checkpoint(post_snapshot(source))
    covered_source =
      Fabricate(
        :post,
        topic: source.topic,
        user: user,
        raw: "Evidence covered only by the latest checkpoint",
      )
    older_carrier = Fabricate(:post, topic: source.topic, user: bot_user)
    PostCustomPrompt.create!(post_id: older_carrier.id, custom_prompt: older_entries)
    Fabricate(:post, topic: source.topic, user: other_user)
    newer_entries = checkpoint(post_snapshot(covered_source))
    newer_entries.each { |entry| entry[7] = nil }
    newer_carrier = Fabricate(:post, topic: source.topic, user: bot_user)
    PostCustomPrompt.create!(post_id: newer_carrier.id, custom_prompt: newer_entries)
    latest = Fabricate(:post, topic: source.topic, user: user)

    expect { post_messages(latest) }.to raise_error(
      DiscourseAi::Completions::ContextPreparation::Error,
      /history_changed/,
    )
  end

  it "preserves the coverage of an already stamped checkpoint" do
    entries = checkpoint(post_snapshot(source))
    latest = Fabricate(:post, topic: source.topic, user: user)
    post_snapshot(latest).stamp!(entries)
    expect(entries.first[6]["source_id"]).to eq(source.id)
  end

  it "retains a cache after rebaking and incidental revisions, and rebuilds after a raw edit" do
    original_snapshot = post_snapshot(source)
    entries = checkpoint(original_snapshot)
    reply = Fabricate(:post, topic: source.topic, user: bot_user, raw: "Visible answer")
    PostCustomPrompt.create!(post_id: reply.id, custom_prompt: entries)
    latest = Fabricate(:post, topic: source.topic, user: user, raw: "Follow-up request")

    source.rebake!
    source.update_columns(updated_at: 1.hour.from_now, version: source.version + 1)
    source.topic.update!(title: "Changed conversation title")
    expect(post_messages(latest).to_s).to include(entries.first.first)

    source.update!(raw: "Corrected original evidence")
    rebuilt = post_messages(latest).to_s
    expect(rebuilt).to include(source.raw, reply.raw, latest.raw)
    expect(rebuilt).not_to include(entries.first.first)
  end

  it "rebuilds from eligible originals after deletion or participant and permission changes" do
    earlier = Fabricate(:post, topic: source.topic, user: user, raw: "Evidence to delete")
    entries = checkpoint(post_snapshot(earlier))
    reply = Fabricate(:post, topic: source.topic, user: bot_user, raw: "Visible answer")
    PostCustomPrompt.create!(post_id: reply.id, custom_prompt: entries)
    latest = Fabricate(:post, topic: source.topic, user: user)

    earlier.trash!
    rebuilt = post_messages(latest).to_s
    expect(rebuilt).to include(source.raw, reply.raw)
    expect(rebuilt).not_to include(earlier.raw, entries.first.first)

    source.topic.topic_allowed_users.create!(user: other_user)
    other_latest = Fabricate(:post, topic: source.topic, user: other_user, raw: "Another reader")
    other_messages = post_messages(other_latest, other_user).to_s
    expect(other_messages).to include(source.raw, reply.raw)
    expect(other_messages).not_to include(entries.first.first)

    group = Fabricate(:group)
    group.add(user)
    user.update!(trust_level: 2)
    expect(post_messages(latest).to_s).not_to include(entries.first.first)
  end

  it "replays only the current reader's authorized tool batches in shared PMs" do
    source.topic.topic_allowed_users.create!(user: other_user)
    private_category = Fabricate(:private_category, group: Fabricate(:group))
    private_post =
      Fabricate(
        :post,
        topic: Fabricate(:topic, category: private_category),
        raw: "Restricted category read result",
      )
    first_entries = [
      %w[{"arguments":{}} read-a tool_call read],
      [private_post.raw, "read-a", "tool", "read"],
      ["Publicly visible answer A", bot_user.username],
    ]
    post_snapshot(source).stamp!(first_entries)
    first_reply =
      Fabricate(:post, topic: source.topic, user: bot_user, raw: "Publicly visible answer A")
    PostCustomPrompt.create!(post_id: first_reply.id, custom_prompt: first_entries)
    second_request = Fabricate(:post, topic: source.topic, user: other_user)
    second_entries = [
      %w[{"arguments":{}} read-b tool_call read],
      ["Permitted evidence for B", "read-b", "tool", "read"],
      ["Publicly visible answer B", bot_user.username],
    ]
    post_snapshot(second_request, other_user).stamp!(second_entries)
    second_reply =
      Fabricate(:post, topic: source.topic, user: bot_user, raw: "Publicly visible answer B")
    PostCustomPrompt.create!(post_id: second_reply.id, custom_prompt: second_entries)
    latest = Fabricate(:post, topic: source.topic, user: other_user)

    prompt = post_messages(latest, other_user).to_s
    expect(prompt).to include(first_reply.raw, second_entries[1][0])
    expect(prompt).not_to include(private_post.raw)
    expect(post_messages(latest).to_s).to include(private_post.raw)
  end

  it "rebuilds a checkpoint after promotions while retaining the reader's still-permitted original tools" do
    entries = [
      %w[{"arguments":{}} permitted-read tool_call read],
      ["Permitted original tool evidence", "permitted-read", "tool", "read"],
      ["Visible answer", bot_user.username],
    ]
    post_snapshot(source).stamp!(entries)
    reply = Fabricate(:post, topic: source.topic, user: bot_user, raw: "Visible answer")
    PostCustomPrompt.create!(post_id: reply.id, custom_prompt: entries)
    latest = Fabricate(:post, topic: source.topic, user: user)
    group = Fabricate(:group)
    group.add(user)
    user.update!(trust_level: 2)
    rebuilt = post_messages(latest).to_s
    expect(rebuilt).to include(entries[1][0], source.raw)
  end

  it "invalidates reader-owned tool evidence after category access is revoked" do
    group = Fabricate(:group)
    group.add(user)
    category = Fabricate(:private_category, group: group)
    private_post =
      Fabricate(
        :post,
        topic: Fabricate(:topic, category: category),
        raw: "Previously permitted private read result",
      )
    entries = [
      %w[{"arguments":{}} private-read tool_call read],
      [private_post.raw, "private-read", "tool", "read"],
      ["Visible answer", bot_user.username],
    ]
    post_snapshot(source).stamp!(entries)
    reply = Fabricate(:post, topic: source.topic, user: bot_user, raw: "Visible answer")
    PostCustomPrompt.create!(post_id: reply.id, custom_prompt: entries)
    latest = Fabricate(:post, topic: source.topic, user: user)
    expect(post_messages(latest).to_s).to include(private_post.raw)

    group.remove(user)
    rebuilt = post_messages(latest).to_s
    expect(rebuilt).to include(reply.raw)
    expect(rebuilt).not_to include(private_post.raw)
  end

  it "does not reforce the first-turn tool on a later unthreaded DM request" do
    channel = Fabricate(:direct_message_channel, users: [user, bot_user])
    Fabricate(:chat_message, chat_channel: channel, user: user)
    Fabricate(:chat_message, chat_channel: channel, user: bot_user)
    latest = Fabricate(:chat_message, chat_channel: channel, user: user)
    snapshot = described_class.chat(latest, guardian: user.guardian, bot_user_ids: [bot_user.id])
    agent_record = Fabricate(:ai_agent, tools: [["ListCategories", {}, true]], forced_tool_count: 1)
    model = Fabricate(:fake_model)
    bot =
      DiscourseAi::Agents::Bot.as(bot_user, agent: agent_record.class_instance.new, model: model)
    messages =
      DiscourseAi::Completions::PromptMessagesBuilder.messages_from_chat(
        latest,
        channel: channel,
        context_post_ids: nil,
        max_messages: 1,
        bot_user_ids: [bot_user.id],
        history_snapshot: snapshot,
      )
    context = DiscourseAi::Agents::BotContext.new(user: user, messages: messages)
    context.user_turn_count = snapshot.user_turn_count
    DiscourseAi::Completions::Llm.with_prepared_responses(
      ["Answer without a forced tool"],
    ) do |_, _, prompts|
      bot.reply(context)
      expect(prompts.first.tool_choice).to be_nil
    end
  end

  it "recovers more than a raw-history page without omitting the original request" do
    builder = DiscourseAi::Completions::PromptMessagesBuilder
    stub_const(builder, :MAX_CONTEXT_MESSAGES, 3) do
      rows =
        (builder::MAX_CONTEXT_MESSAGES + 1).times.map do |index|
          {
            topic_id: source.topic_id,
            user_id: user.id,
            post_number: index + 2,
            raw: "Earlier request #{index}",
            cooked: "Earlier request #{index}",
            post_type: Post.types[:regular],
            created_at: Time.current,
            updated_at: Time.current,
            last_version_at: Time.current,
          }
        end
      Post.insert_all!(rows)
      latest = source.topic.posts.order(:post_number).last
      prompt = post_messages(latest).to_s
      expect(prompt).to include(source.raw, *rows.map { |row| row[:raw] }, latest.raw)
    end
  end

  it "makes public context scoping explicit instead of permanently failing long topics" do
    topic = Fabricate(:topic)
    first = Fabricate(:post, topic: topic, user: user, raw: "Outside the explicit scope")
    now = Time.current
    rows =
      45.times.map do |index|
        {
          topic_id: topic.id,
          user_id: user.id,
          post_number: index + 2,
          raw: "Scoped request #{index}",
          cooked: "<p>Scoped request #{index}</p>",
          post_type: Post.types[:regular],
          created_at: now,
          updated_at: now,
          last_version_at: now,
        }
      end
    Post.insert_all!(rows)
    latest = topic.posts.order(:post_number).last

    prompt = post_messages(latest).to_s
    expect(prompt).to include("Public context is scoped", latest.raw)
    expect(prompt).not_to include(first.raw)
  end

  it "counts the full unthreaded DM history and invalidates evidence after an older edit" do
    channel = Fabricate(:direct_message_channel, users: [user, bot_user])
    first =
      Fabricate(
        :chat_message,
        chat_channel: channel,
        user: user,
        message: "Remember an earlier request",
      )
    reply =
      Fabricate(:chat_message, chat_channel: channel, user: bot_user, message: "Read complete")
    latest = Fabricate(:chat_message, chat_channel: channel, user: user, message: "Follow-up")
    snapshot = described_class.chat(latest, guardian: user.guardian, bot_user_ids: [bot_user.id])
    expect(snapshot.user_turn_count).to eq(2)
    messages =
      DiscourseAi::Completions::PromptMessagesBuilder.messages_from_chat(
        latest,
        channel: channel,
        context_post_ids: nil,
        max_messages: 1,
        bot_user_ids: [bot_user.id],
        history_snapshot: snapshot,
      )
    expect(messages.map { |entry| entry[:content] }).to eq(
      [first.message, reply.message, latest.message],
    )
    first.update!(message: "Corrected older DM request")
    expect { snapshot.verify! }.to raise_error(
      DiscourseAi::Completions::ContextPreparation::Error,
      /history_changed/,
    )
  end

  it "invalidates chat evidence when an approval card outcome changes without a raw edit" do
    channel = Fabricate(:direct_message_channel, users: [user, bot_user])
    card = Fabricate(:chat_message, chat_channel: channel, user: bot_user)
    card.update!(
      blocks:
        DiscourseAi::AiBot::ChatToolApproval.pending_blocks(
          7,
          info: {
            summary: "Change site setting",
            details: card.message,
            question: "Do you want to make this change?",
            parameters: [],
          },
        ),
    )
    latest = Fabricate(:chat_message, chat_channel: channel, user: user)
    snapshot = described_class.chat(latest, guardian: user.guardian, bot_user_ids: [bot_user.id])
    original_message = card.message

    DiscourseAi::AiBot::ChatToolApproval.resolve_message!(card, "Approved")

    expect(card.reload.message).to eq(original_message)
    expect { snapshot.verify! }.to raise_error(
      DiscourseAi::Completions::ContextPreparation::Error,
      /history_changed/,
    )
  end

  it "keeps private tool results reader-specific in group DMs and public threads" do
    [
      Fabricate(:direct_message_channel, users: [user, other_user, bot_user]),
      Fabricate(:category_channel),
    ].each do |channel|
      source_message =
        Fabricate(
          :chat_message,
          chat_channel: channel,
          user: user,
          message: "Read a restricted topic",
        )
      thread =
        Fabricate(:chat_thread, channel: channel, original_message: source_message, force: true)
      source_message.reload
      entries = [
        %w[{"arguments":{}} private-read tool_call read],
        ["Private result for A", "private-read", "tool", "read"],
        ["Visible bot reply", bot_user.username],
      ]
      described_class.chat(
        source_message,
        guardian: user.guardian,
        bot_user_ids: [bot_user.id],
      ).stamp!(entries)
      bot_message =
        Fabricate(
          :chat_message,
          chat_channel: channel,
          thread: thread,
          user: bot_user,
          message: "Visible bot reply",
        )
      ChatMessageCustomPrompt.create!(message_id: bot_message.id, custom_prompt: entries)
      latest =
        Fabricate(
          :chat_message,
          chat_channel: channel,
          thread: thread,
          user: other_user,
          message: "Follow-up B",
        )
      snapshot =
        described_class.chat(latest, guardian: other_user.guardian, bot_user_ids: [bot_user.id])
      messages =
        DiscourseAi::Completions::PromptMessagesBuilder.messages_from_chat(
          latest,
          channel: channel,
          context_post_ids: nil,
          max_messages: 2,
          bot_user_ids: [bot_user.id],
          history_snapshot: snapshot,
        )
      expect(messages.to_s).to include(bot_message.message, latest.message)
      expect(messages.to_s).not_to include(entries[1][0])
    end
  end
end
