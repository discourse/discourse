# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::WorkflowChatTrigger::V1, if: defined?(Chat) do
  fab!(:user)
  fab!(:bot)
  fab!(:conversation) do
    Fabricate(:discourse_workflows_chat_conversation, user:, bot_user: bot, workflow_id: 1)
  end

  let(:channel) { conversation.channel }

  before { SiteSetting.chat_enabled = true }

  def post_message(author, text, **attributes)
    Fabricate(
      :chat_message_without_service,
      chat_channel: channel,
      user: author,
      message: text,
      **attributes,
    )
  end

  it "keeps the identifier saved workflows refer to" do
    expect(described_class.identifier).to eq("trigger:workflow_chat")
  end

  it "declares where a member starts it and that it provides the current user" do
    expect(described_class.capabilities).to include(
      launch_path: "/workflows/chat/:workflow_id/:node_id",
      provides_current_user: true,
    )
  end

  it "is configured by its allowed groups alone" do
    expect(described_class.property_schema.keys).to contain_exactly(
      :url_preview,
      :chat_title,
      :welcome_message,
      :chat_bot_id,
      :group_ids,
    )
  end

  describe ".load_options_context" do
    def load_options(method_name, filter: nil)
      described_class.load_options_context(
        DiscourseWorkflows::LoadOptionsContext.new(
          method_name:,
          filter:,
          node_class: described_class,
        ),
      )
    end

    it "offers the bots that can be used, not people" do
      inactive_bot = Fabricate(:bot, active: false)
      suspended_bot = Fabricate(:bot, suspended_till: 1.day.from_now, suspended_at: Time.zone.now)

      ids = load_options("chat_bots").map { |option| option[:id] }

      expect(ids).to include(bot.id, Discourse::SYSTEM_USER_ID)
      expect(ids).not_to include(user.id, inactive_bot.id, suspended_bot.id)
      expect(load_options("chat_bots", filter: bot.username)).to eq(
        [{ id: bot.id, name: bot.username }],
      )
    end

    it "offers groups matching the filter" do
      group = Fabricate(:group, name: "helpdesk_members")

      expect(load_options("groups", filter: "helpdesk")).to eq([{ id: group.id, name: group.name }])
    end
  end

  describe "#output" do
    it "describes the message and its author" do
      SiteSetting.chat_allow_uploads = true
      upload = Fabricate(:upload, user:)
      message = post_message(user, "How do I start?", uploads: [upload])

      output = described_class.new(message, conversation).output

      expect(output).to include(
        "chatInput" => "How do I start?",
        "channel_id" => channel.id,
        "sessionId" => channel.id.to_s,
        "message" => {
          "id" => message.id,
          "content" => "How do I start?",
          "upload_ids" => [upload.id],
        },
        "history" => [],
        "user" => include(id: user.id, username: user.username),
        "actor" => include(id: user.id, username: user.username),
      )
      expect(output.deep_stringify_keys).to match_node_output_schema(described_class)
    end

    it "lists the earlier turns of the member and the bot, oldest first" do
      added_user = Fabricate(:user)
      post_message(bot, "Welcome")
      post_message(user, "First question")
      post_message(user, "Deleted question", deleted_at: Time.zone.now)
      post_message(added_user, "Someone else's message")
      post_message(Discourse.system_user, "A system notice")
      post_message(bot, "First answer")
      post_message(bot, "More details")
      message = post_message(user, "Follow-up")
      post_message(bot, "Later answer")

      output = described_class.new(message, conversation).output

      expect(output["history"]).to eq(
        [
          { "role" => "assistant", "content" => "Welcome" },
          { "role" => "user", "content" => "First question" },
          { "role" => "assistant", "content" => "First answer" },
          { "role" => "assistant", "content" => "More details" },
        ],
      )
      expect(output.deep_stringify_keys).to match_node_output_schema(described_class)
    end

    it "leaves out messages without text" do
      post_message(user, "", uploads: [Fabricate(:upload, user:)])
      post_message(user, "Question")
      message = post_message(user, "Follow-up")

      expect(described_class.new(message, conversation).output["history"]).to eq(
        [{ "role" => "user", "content" => "Question" }],
      )
    end

    it "keeps the most recent turns only" do
      turns = (1..described_class::HISTORY_LIMIT + 1).map { |index| "Turn #{index}" }
      turns.each { |turn| post_message(user, turn) }
      message = post_message(user, "Latest")

      history = described_class.new(message, conversation).output["history"]

      expect(history.map { |turn| turn["content"] }).to eq(turns.drop(1))
    end
  end
end
