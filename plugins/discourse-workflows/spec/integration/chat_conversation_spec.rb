# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::ChatConversation, if: defined?(Chat) do
  fab!(:user)
  fab!(:other_user, :user)
  fab!(:admin)
  fab!(:group)

  let(:effect_url) { "https://workflow.example.test/effect" }
  let(:checkpoint_url) { "https://workflow.example.test/checkpoint" }
  let(:http_success) do
    { status: 200, body: "{}", headers: { "content-type" => "application/json" } }
  end
  let(:job) { Jobs::DiscourseWorkflows::RunChatConversation }

  before do
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:logged_in_users]
    SiteSetting.enable_discourse_workflows = true
    SiteSetting.direct_message_enabled_groups = Group::AUTO_GROUPS[:logged_in_users]
    group.add(user)
  end

  def chat_trigger(builder, **configuration)
    builder.node(
      "chat",
      "trigger:workflow_chat",
      configuration: {
        group_ids: [group.id],
        **configuration,
      },
    )
  end

  def reply_node(builder, message)
    builder.node("reply", "action:respond_to_chat", configuration: { message: })
  end

  def workflow_chat(published: true, reply: "={{ $json.chatInput }}", trigger: {})
    graph =
      build_workflow_graph do |builder|
        chat_trigger(builder, **trigger)
        reply_node(builder, reply)
        builder.connect("chat", "reply")
      end
    Fabricate(:discourse_workflows_workflow, published:, **graph)
  end

  def workflow_chat_with_effect(checkpoint: false, reply: false)
    graph =
      build_workflow_graph do |builder|
        chat_trigger(builder)
        builder.node(
          "effect",
          "action:http_request",
          parameters: {
            method: "POST",
            url: effect_url,
          },
        )
        if checkpoint
          builder.node(
            "checkpoint",
            "action:http_request",
            parameters: {
              method: "GET",
              url: checkpoint_url,
            },
          )
        end
        reply_node(builder, "Done") if reply
        builder.chain(*builder.to_h[:nodes].map { |node| node["id"] })
      end
    Fabricate(:discourse_workflows_workflow, published: true, **graph)
  end

  def open_chat(workflow, member: user, draft: false)
    described_class::Open.call(
      guardian: member.guardian,
      params: {
        workflow_id: workflow.id,
        node_id: "chat",
        draft:,
      },
    )
  end

  def send_message(channel, text, member: user, upload_ids: [])
    Chat::CreateMessage.call(
      guardian: member.guardian,
      params: {
        chat_channel_id: channel.id,
        message: text,
        upload_ids:,
      },
    )
  end

  def add_to_chat(channel, added_user, by: user)
    result =
      Chat::AddUsersToChannel.call(
        guardian: by.guardian,
        params: {
          channel_id: channel.id,
          usernames: [added_user.username],
        },
      )
    expect(result).to run_successfully
  end

  def messages_in(channel)
    channel.chat_messages.order(:id).pluck(:user_id, :message)
  end

  def queued_message_ids
    job.jobs.map { |queued| queued["args"].first["message_id"] }
  end

  def no_conversation
    I18n.t("discourse_workflows.errors.respond_to_chat.no_conversation")
  end

  describe "opening a conversation" do
    it "binds a new DM to the member, the bot and the trigger on every launch" do
      workflow = workflow_chat(trigger: { chat_title: "Help desk" })

      first_chat = open_chat(workflow)
      second_chat = open_chat(workflow)

      expect(first_chat).to run_successfully
      expect(second_chat).to run_successfully
      channel = first_chat.channel
      expect(channel).to be_a(Chat::DirectMessageChannel)
      expect(channel.name).to eq("Help desk")
      expect(channel.allowed_user_ids).to contain_exactly(user.id, Discourse.system_user.id)
      expect(second_chat.channel.id).not_to eq(channel.id)
      expect(other_user.guardian.can_preview_chat_channel?(channel)).to eq(false)
      expect(described_class.find_by(channel:)).to have_attributes(
        user:,
        bot_user: Discourse.system_user,
        workflow_id: workflow.id,
        trigger_node_id: "chat",
        draft: false,
      )
    end

    it "names the DM after the published workflow when the trigger has no title" do
      workflow = workflow_chat
      published_name = workflow.name
      workflow.update!(name: "Renamed draft")

      expect(open_chat(workflow).channel.name).to eq(published_name)
    end

    it "is refused for a trigger the member may not chat with" do
      expect(open_chat(workflow_chat, member: other_user)).to fail_to_find_a_model(:trigger)
      expect(open_chat(workflow_chat(trigger: { group_ids: [] }))).to fail_to_find_a_model(:trigger)
      expect(open_chat(workflow_chat(published: false))).to fail_to_find_a_model(:trigger)
      expect(described_class.count).to eq(0)
    end

    it "is refused when the configured bot cannot be used" do
      bot = Fabricate(:bot, active: false)

      expect(open_chat(workflow_chat(trigger: { chat_bot_id: bot.id }))).to fail_to_find_a_model(
        :bot,
      )
      expect(
        open_chat(workflow_chat(trigger: { chat_bot_id: other_user.id })),
      ).to fail_to_find_a_model(:bot)
    end

    it "is refused to a member who cannot create DMs" do
      SiteSetting.direct_message_enabled_groups = Group::AUTO_GROUPS[:staff]

      expect(open_chat(workflow_chat)).to fail_to_find_a_model(:channel)
      expect(described_class.count).to eq(0)
    end

    it "binds a channel to one conversation only" do
      conversation = described_class.find_by(channel: open_chat(workflow_chat).channel)

      expect { described_class.create!(conversation.attributes.except("id")) }.to raise_error(
        ActiveRecord::RecordNotUnique,
      )
    end

    it "posts the welcome message as the configured bot" do
      bot = Fabricate(:bot)
      workflow = workflow_chat(trigger: { chat_bot_id: bot.id, welcome_message: "Welcome" })

      channel = open_chat(workflow).channel

      expect(channel.allowed_user_ids).to contain_exactly(user.id, bot.id)
      expect(messages_in(channel)).to eq([[bot.id, "Welcome"]])
    end
  end

  describe "running the workflow" do
    it "runs once for the member's message and replies as the bot" do
      workflow = workflow_chat(reply: "={{ 'Answer: ' + $json.chatInput }}")
      channel = open_chat(workflow).channel

      Jobs.run_immediately!
      expect(send_message(channel, "How do I start?")).to run_successfully

      question = channel.chat_messages.order(:id).first
      expect(messages_in(channel)).to eq(
        [[user.id, "How do I start?"], [Discourse.system_user.id, "Answer: How do I start?"]],
      )
      execution = workflow.executions.sole
      expect(execution).to be_success.and be_normal
      expect(execution.trigger_data).to include(
        "chatInput" => "How do I start?",
        "channel_id" => channel.id,
        "sessionId" => channel.id.to_s,
        "message" => {
          "id" => question.id,
          "content" => "How do I start?",
          "upload_ids" => [],
        },
        "history" => [],
        "user" => include("id" => user.id),
        "actor" => include("id" => user.id),
      )
      expect(execution.trigger_data).to match_node_output_schema(
        DiscourseWorkflows::Nodes::WorkflowChatTrigger::V1,
      )
    end

    it "gives the workflow the earlier turns of the conversation" do
      workflow = workflow_chat(reply: "Reply", trigger: { welcome_message: "Welcome" })
      channel = open_chat(workflow).channel

      Jobs.run_immediately!
      send_message(channel, "First question")
      send_message(channel, "Follow-up")

      expect(workflow.executions.order(:id).last.trigger_data["history"]).to eq(
        [
          { "role" => "assistant", "content" => "Welcome" },
          { "role" => "user", "content" => "First question" },
          { "role" => "assistant", "content" => "Reply" },
        ],
      )
    end

    it "replies as the configured bot" do
      bot = Fabricate(:bot)
      workflow = workflow_chat(trigger: { chat_bot_id: bot.id })
      channel = open_chat(workflow).channel

      Jobs.run_immediately!
      send_message(channel, "Question")

      expect(messages_in(channel)).to eq([[user.id, "Question"], [bot.id, "Question"]])
    end

    it "passes the message's upload IDs to the workflow" do
      SiteSetting.chat_allow_uploads = true
      upload = Fabricate(:upload, user:)
      workflow = workflow_chat(reply: "={{ 'Files: ' + $json.message.upload_ids.length }}")
      channel = open_chat(workflow).channel

      Jobs.run_immediately!
      send_message(channel, "See attachment", upload_ids: [upload.id])

      expect(channel.chat_messages.order(:id).last.message).to eq("Files: 1")
      expect(workflow.executions.sole.trigger_data.dig("message", "upload_ids")).to eq([upload.id])
    end

    it "replies after the workflow resumes from a wait, when the run has no user" do
      graph =
        build_workflow_graph do |builder|
          chat_trigger(builder)
          builder.node(
            "wait",
            "flow:wait",
            configuration: {
              resume: "time_interval",
              wait_amount: 1,
              wait_unit: "minutes",
            },
          )
          reply_node(builder, "Resumed")
          builder.chain("chat", "wait", "reply")
        end
      workflow = Fabricate(:discourse_workflows_workflow, published: true, **graph)
      channel = open_chat(workflow).channel
      message = send_message(channel, "Question").message_instance
      job.new.execute(message_id: message.id)
      execution = workflow.executions.sole
      expect(execution).to be_waiting
      expect(messages_in(channel)).to eq([[user.id, "Question"]])

      freeze_time(2.minutes.from_now) do
        Jobs::DiscourseWorkflows::ResumeWaitingExecution.new.execute(
          execution_id: execution.id,
          resume_token: execution.resume_token,
        )
      end

      expect(execution.reload).to be_success
      expect(messages_in(channel)).to eq(
        [[user.id, "Question"], [Discourse.system_user.id, "Resumed"]],
      )
    end
  end

  describe "who starts a run" do
    it "queues a run for the conversation's member only" do
      channel = open_chat(workflow_chat).channel
      add_to_chat(channel, other_user)

      intrusion = send_message(channel, "Run it for me", member: other_user).message_instance
      question = send_message(channel, "Question").message_instance

      expect(queued_message_ids).to eq([question.id])
      expect(
        described_class::Run.call(params: { message_id: intrusion.id }),
      ).to fail_to_find_a_model(:conversation)
    end

    it "keeps working for a member who added another user to the DM" do
      bot = Fabricate(:bot)
      workflow = workflow_chat(reply: "Reply", trigger: { chat_bot_id: bot.id })
      channel = open_chat(workflow).channel
      add_to_chat(channel, other_user)

      Jobs.run_immediately!
      send_message(channel, "Run it for me", member: other_user)
      send_message(channel, "Question")

      expect(channel.chat_messages.where(user: bot).pluck(:message)).to eq(["Reply"])
      expect(workflow.executions.sole.trigger_data).to include(
        "chatInput" => "Question",
        "history" => [],
      )
    end

    it "never queues a run for the bot's reply" do
      workflow = workflow_chat(reply: "Reply")
      channel = open_chat(workflow).channel
      message = send_message(channel, "Question").message_instance

      job.new.execute(message_id: message.id)

      expect(messages_in(channel)).to eq(
        [[user.id, "Question"], [Discourse.system_user.id, "Reply"]],
      )
      expect(queued_message_ids).to eq([message.id])
    end

    it "leaves DMs that are not workflow conversations alone" do
      direct_message = Fabricate(:direct_message_channel, users: [user, Discourse.system_user])
      group_direct_message =
        Fabricate(:direct_message_channel, users: [user, Discourse.system_user], group: true)

      expect(send_message(direct_message, "Hello")).to run_successfully
      expect(send_message(group_direct_message, "Hello")).to run_successfully

      expect(job.jobs).to be_empty
    end

    it "queues nothing while workflows are disabled" do
      channel = open_chat(workflow_chat).channel
      SiteSetting.enable_discourse_workflows = false

      expect(send_message(channel, "Question")).to run_successfully

      expect(job.jobs).to be_empty
    end
  end

  describe "re-resolving the trigger for every run" do
    it "skips a queued run when the member left the trigger's allowed groups" do
      workflow = workflow_chat
      channel = open_chat(workflow).channel
      message = send_message(channel, "Question").message_instance
      expect_job_enqueued(job:, args: { message_id: message.id })

      group.remove(user)
      job.drain

      expect(workflow.executions).to be_empty
      expect(messages_in(channel)).to eq([[user.id, "Question"]])
    end

    it "skips a queued run when the workflow was unpublished" do
      workflow = workflow_chat
      channel = open_chat(workflow).channel
      message = send_message(channel, "Question").message_instance

      unpublish_workflow!(workflow)
      result = described_class::Run.call(params: { message_id: message.id })

      expect(result).to fail_to_find_a_model(:trigger)
      expect(workflow.executions).to be_empty
    end

    it "skips a queued run when the message was deleted" do
      workflow = workflow_chat
      channel = open_chat(workflow).channel
      message = send_message(channel, "Question").message_instance

      message.trash!
      job.new.execute(message_id: message.id)

      expect(workflow.executions).to be_empty
    end

    it "runs the version published since the conversation was opened" do
      workflow = workflow_chat(reply: "First version")
      channel = open_chat(workflow).channel
      update_workflow_node(workflow, "reply") do |node|
        node.merge("parameters" => node["parameters"].merge("message" => "Second version"))
      end
      publish_workflow!(workflow)

      Jobs.run_immediately!
      send_message(channel, "Question")

      expect(channel.chat_messages.order(:id).last.message).to eq("Second version")
    end
  end

  describe "draft conversations" do
    it "runs the unpublished draft for a user who can manage workflows" do
      workflow = workflow_chat(published: false, reply: "Draft reply")
      expect(open_chat(workflow, draft: true)).to fail_to_find_a_model(:trigger)

      result = open_chat(workflow, member: admin, draft: true)

      expect(result).to run_successfully
      channel = result.channel
      expect(described_class.find_by(channel:)).to have_attributes(user: admin, draft: true)
      expect(channel.chat_messages.sole.message).to eq(
        I18n.t("discourse_workflows.workflow_chat.draft_notice"),
      )

      Jobs.run_immediately!
      send_message(channel, "Test the draft", member: admin)

      expect(channel.chat_messages.order(:id).last.message).to eq("Draft reply")
      expect(workflow.executions.sole).to be_success.and be_manual
    end

    it "starts with the draft notice followed by the welcome message" do
      workflow = workflow_chat(published: false, trigger: { welcome_message: "Welcome" })

      channel = open_chat(workflow, member: admin, draft: true).channel

      expect(channel.chat_messages.sole.message).to eq(
        "#{I18n.t("discourse_workflows.workflow_chat.draft_notice")}\n\nWelcome",
      )
    end

    it "runs the draft even when another version is published" do
      workflow = workflow_chat(reply: "Published reply")
      update_workflow_node(workflow, "reply") do |node|
        node.merge("parameters" => node["parameters"].merge("message" => "Draft reply"))
      end
      channel = open_chat(workflow, member: admin, draft: true).channel

      Jobs.run_immediately!
      send_message(channel, "Test the draft", member: admin)

      expect(channel.chat_messages.order(:id).last.message).to eq("Draft reply")
    end

    it "stops running once its member can no longer manage workflows" do
      workflow = workflow_chat(published: false, reply: "Draft reply")
      channel = open_chat(workflow, member: admin, draft: true).channel
      admin.revoke_admin!

      Jobs.run_immediately!
      expect(send_message(channel, "Test the draft", member: admin.reload)).to run_successfully

      expect(workflow.executions).to be_empty
      expect(channel.chat_messages.where(user: Discourse.system_user).pluck(:message)).to eq(
        [I18n.t("discourse_workflows.workflow_chat.draft_notice")],
      )
    end

    it "does not fall back to the published trigger for a former manager" do
      workflow = workflow_chat(reply: "Published reply")
      group.add(admin)
      channel = open_chat(workflow, member: admin, draft: true).channel
      admin.revoke_admin!
      message = send_message(channel, "Test the draft", member: admin.reload).message_instance

      expect(described_class::Run.call(params: { message_id: message.id })).to fail_to_find_a_model(
        :trigger,
      )
    end
  end

  describe "where a workflow may reply" do
    def error_of(workflow)
      workflow.executions.sole.then { |execution| [execution.status, execution.error] }
    end

    it "refuses to reply in a conversation of another workflow" do
      channel = open_chat(workflow_chat).channel
      graph =
        build_workflow_graph do |builder|
          builder.node("chat", "trigger:manual")
          reply_node(builder, "Leaked")
          builder.connect("chat", "reply")
        end
      intruder = Fabricate(:discourse_workflows_workflow, published: true, **graph)

      DiscourseWorkflows::Executor.new(intruder, "chat", { "channel_id" => channel.id }).run

      expect(error_of(intruder)).to match(["error", include(no_conversation)])
      expect(channel.chat_messages).to be_empty
    end

    it "refuses to reply from a run that another trigger of the workflow started" do
      graph =
        build_workflow_graph do |builder|
          chat_trigger(builder)
          builder.node("start", "trigger:manual")
          reply_node(builder, "Leaked")
          builder.connect("chat", "reply")
          builder.connect("start", "reply")
        end
      workflow = Fabricate(:discourse_workflows_workflow, published: true, **graph)
      channel = open_chat(workflow).channel

      DiscourseWorkflows::Executor.new(workflow, "start", { "channel_id" => channel.id }).run

      expect(error_of(workflow)).to match(["error", include(no_conversation)])
      expect(channel.chat_messages).to be_empty
    end

    it "refuses to reply in a conversation whose channel was closed" do
      workflow = workflow_chat(reply: "Reply")
      channel = open_chat(workflow).channel
      message = send_message(channel, "Question").message_instance
      channel.update!(status: :closed)

      job.new.execute(message_id: message.id)

      expect(error_of(workflow)).to match(["error", include(no_conversation)])
      expect(messages_in(channel)).to eq([[user.id, "Question"]])
    end
  end

  describe "running at most once per message" do
    it "runs once when a duplicate job arrives while the first is running" do
      workflow = workflow_chat_with_effect(reply: true)
      channel = open_chat(workflow).channel
      message = send_message(channel, "Question").message_instance
      duplicate_delivered = false
      stub_request(:post, effect_url).to_return do
        unless duplicate_delivered
          duplicate_delivered = true
          job.new.execute(message_id: message.id)
        end
        http_success
      end

      job.new.execute(message_id: message.id)

      expect(a_request(:post, effect_url)).to have_been_made.once
      expect(channel.chat_messages.order(:id).pluck(:message)).to eq(%w[Question Done])
    end

    it "does not run again when the job is redelivered after a shutdown interrupted it" do
      workflow = workflow_chat_with_effect(checkpoint: true, reply: true)
      stub_request(:post, effect_url).to_return(http_success)
      stub_request(:get, checkpoint_url).to_raise(Sidekiq::Shutdown).then.to_return(http_success)
      channel = open_chat(workflow).channel
      message = send_message(channel, "Question").message_instance

      expect { job.new.execute(message_id: message.id) }.to raise_error(Sidekiq::Shutdown)
      job.new.execute(message_id: message.id)

      expect(a_request(:post, effect_url)).to have_been_made.once
      expect(workflow.executions.sole).to be_error
      expect(channel.chat_messages).to contain_exactly(message)
    end

    it "runs once when the same message is processed twice" do
      workflow = workflow_chat_with_effect
      stub_request(:post, effect_url).to_return(http_success)
      channel = open_chat(workflow).channel
      message = send_message(channel, "Question").message_instance

      2.times { job.new.execute(message_id: message.id) }

      expect(a_request(:post, effect_url)).to have_been_made.once
      expect(workflow.executions.sole).to be_success
    end
  end

  describe "cost of watching chat messages" do
    let(:conversation_lookup) do
      match(
        /FROM "discourse_workflows_chat_conversations" WHERE .*"channel_id" = \? AND .*"user_id" = \?/,
      )
    end

    # Two messages never share their literals, so their queries are compared by shape.
    def message_query_shapes(channel, workflows:, member: user)
      SiteSetting.enable_discourse_workflows = workflows
      # The first message after a setting change also repopulates caches.
      send_message(channel, "Warm-up with workflows #{workflows}", member:)
      track_sql_queries do
        send_message(channel, "Measured with workflows #{workflows}", member:)
      end.map { |sql| sql.gsub(/'(?:[^']|'')*'|\b\d+\b/, "?") }
    end

    def queries_added_by_workflows(channel, **options)
      without_workflows = message_query_shapes(channel, workflows: false, **options).tally

      message_query_shapes(channel, workflows: true, **options).select do |shape|
        next true if without_workflows[shape].to_i.zero?

        without_workflows[shape] -= 1
        false
      end
    end

    it "adds no query to a message in a category channel" do
      channel = Fabricate(:chat_channel)
      channel.add(user)

      expect(queries_added_by_workflows(channel)).to eq([])
    end

    it "adds no query to a message in a 1:1 DM" do
      channel = Fabricate(:direct_message_channel, users: [user, other_user])

      expect(queries_added_by_workflows(channel)).to eq([])
    end

    it "adds one lookup by the indexed channel to a message in a group DM" do
      channel = Fabricate(:direct_message_channel, users: [user, other_user, admin])

      expect(queries_added_by_workflows(channel)).to contain_exactly(conversation_lookup)
    end

    it "adds the same single lookup to a message in a workflow conversation" do
      channel = open_chat(workflow_chat).channel

      expect(queries_added_by_workflows(channel)).to contain_exactly(conversation_lookup)
    end

    it "adds no query to a bot's message in a workflow conversation" do
      channel = open_chat(workflow_chat).channel

      expect(queries_added_by_workflows(channel, member: Discourse.system_user)).to eq([])
    end
  end
end
