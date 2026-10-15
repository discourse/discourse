# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::SendChatMessage::V1 do
  fab!(:channel, :chat_channel)

  before { SiteSetting.chat_enabled = true }

  def node_error(key, scope: :send_chat_message, item_index: 0, **args)
    node_error_message(key, scope:, item_index:, **args)
  end

  def log_messages(ctx)
    ctx.log.entries.map { |entry| entry["message"] }
  end

  def hint_messages(ctx)
    ctx.execution_hints.map { |hint| hint["message"] }
  end

  def sent_log(target, message, item_index: 0, **args)
    I18n.t(
      "discourse_workflows.logs.send_chat_message.sent_to_#{target}",
      item_index:,
      message_id: message.id,
      **args,
    )
  end

  def hint(key, **args)
    I18n.t("discourse_workflows.hints.send_chat_message.#{key}", **args)
  end

  describe ".load_options_context" do
    fab!(:other_channel) { Fabricate(:chat_channel, name: "Announcements") }
    fab!(:closed_channel) { Fabricate(:chat_channel, name: "Closed", status: :closed) }
    fab!(:dm_channel, :direct_message_channel)

    def load_options(filter: nil)
      context =
        DiscourseWorkflows::LoadOptionsContext.new(
          method_name: "chat_channels",
          filter: filter,
          node_class: described_class,
        )

      described_class.load_options_context(context)
    end

    it "returns open public channels with id and name" do
      ids = load_options.map { |option| option[:id] }

      expect(ids).to include(channel.id, other_channel.id)
      expect(ids).not_to include(closed_channel.id, dm_channel.id)
    end

    it "falls back to category name when channel name is blank" do
      blank_channel = Fabricate(:chat_channel, name: nil)

      option = load_options.find { |opt| opt[:id] == blank_channel.id }

      expect(option[:name]).to eq(blank_channel.chatable.name)
    end

    it "filters channels by the filter term" do
      expect(load_options(filter: "announce")).to contain_exactly(
        { id: other_channel.id, name: other_channel.name },
      )
    end

    it "limits channel options after applying the filter" do
      201.times { |index| Fabricate(:chat_channel, name: "Load option channel #{index}") }
      matching_channel = Fabricate(:chat_channel, name: "Targeted workflow channel")

      expect(load_options.size).to eq(
        DiscourseWorkflows::Nodes::ChatChannelSelection::MAX_LOAD_OPTIONS,
      )
      expect(load_options(filter: "targeted")).to contain_exactly(
        { id: matching_channel.id, name: matching_channel.name },
      )
    end
  end

  describe "#execute" do
    it "sends the message resolved for each input item and logs each send" do
      log = nil

      output =
        execute_node_output(
          configuration: {
            "channel_id" => "={{ $json.target_channel }}",
            "message" => "={{ $json.text }}",
          },
          input_items: [
            { "json" => { "target_channel" => channel.id, "text" => "First message" } },
            { "json" => { "target_channel" => channel.id, "text" => "Second message" } },
          ],
        ) { |ctx| log = log_messages(ctx) }

      first, second = channel.chat_messages.order(:id).last(2)
      expect(output.first.map { |item| item["json"] }).to eq(
        [
          { "channel_id" => channel.id, "message_id" => first.id, "message" => "First message" },
          { "channel_id" => channel.id, "message_id" => second.id, "message" => "Second message" },
        ],
      )
      expect([first, second].map(&:message)).to eq(["First message", "Second message"])
      expect(log).to eq(
        [
          sent_log(:channel, first, channel_id: channel.id),
          sent_log(:channel, second, item_index: 1, channel_id: channel.id),
        ],
      )
    end

    it "rejects expression-resolved channels outside the selectable channel scope" do
      closed_channel = Fabricate(:chat_channel, name: "Closed", status: :closed)

      expect {
        execute_node_output(
          configuration: {
            "channel_id" => "={{ $json.target_channel }}",
            "message" => "Hidden target",
          },
          item: {
            "json" => {
              "target_channel" => closed_channel.id,
            },
          },
        )
      }.to raise_error(
        DiscourseWorkflows::NodeError,
        node_error(:channel_not_found, channel_id: closed_channel.id),
      )
      expect(closed_channel.chat_messages).to be_empty
    end

    it "rejects direct message channels outside the selectable channel scope" do
      dm_channel = Fabricate(:direct_message_channel)

      expect {
        execute_node_output(
          configuration: {
            "channel_id" => dm_channel.id.to_s,
            "message" => "Hidden target",
          },
        )
      }.to raise_error(
        DiscourseWorkflows::NodeError,
        node_error(:channel_not_found, channel_id: dm_channel.id.to_s),
      )
      expect(dm_channel.chat_messages).to be_empty
    end

    it "explains why the channel refused the message" do
      channel.update!(status: :read_only)
      configuration = { "channel_id" => channel.id.to_s, "message" => "Hello" }
      node = described_class.new(parameters: configuration)
      # Only open channels are selectable, so simulate a status change after selection.
      allow(node).to receive(:selectable_chat_channel).and_return(channel)

      expect { execute_node_output(configuration:, node:) }.to raise_error(
        DiscourseWorkflows::NodeError,
        node_error(
          :channel_blocked,
          channel_id: channel.id,
          reason: I18n.t("chat.errors.channel_new_message_disallowed.read_only"),
        ),
      )
      expect(channel.chat_messages).to be_empty
    end
  end

  describe "#execute with a failing item" do
    let(:configuration) do
      { "channel_id" => "={{ $json.channel_id }}", "message" => "={{ $json.text }}" }
    end
    let(:input_items) do
      [
        { "json" => { "channel_id" => channel.id, "text" => "First" } },
        { "json" => { "channel_id" => -1, "text" => "Second" } },
        { "json" => { "channel_id" => channel.id, "text" => "Third" } },
      ]
    end
    let(:item_error) { node_error(:channel_not_found, item_index: 1, channel_id: -1) }

    it "stops at the failing item by default" do
      expect { execute_node_output(configuration:, input_items:) }.to raise_error(
        DiscourseWorkflows::NodeError,
        item_error,
      )
      expect(channel.chat_messages.sole.message).to eq("First")
    end

    it "reports the failure on its own item when continuing on error" do
      output =
        execute_node_output(
          configuration:,
          input_items:,
          node_settings: {
            "onError" => "continueErrorOutput",
          },
        )

      expect(output.length).to eq(1)
      sent, failed, sent_after = output.first
      expect(channel.chat_messages.order(:id).pluck(:message)).to eq(%w[First Third])
      expect([sent, sent_after].map { |item| item["json"]["message"] }).to eq(%w[First Third])
      expect(output.first.map { |item| item.key?("error") }).to eq([false, true, false])
      expect(failed).to include(
        "json" => {
          "channel_id" => -1,
          "text" => "Second",
        },
        "error" => include("message" => item_error),
        "__failed" => true,
        "pairedItem" => {
          "item" => 1,
        },
      )
    end
  end

  describe "#execute with a user target" do
    fab!(:recipient) { Fabricate(:user, username: "bob", refresh_auto_groups: true) }
    fab!(:sender) { Fabricate(:user, username: "alice", refresh_auto_groups: true) }

    def send_dm(input_items: nil, node_settings: {}, **parameters, &block)
      execute_node_output(
        configuration: {
          "target" => "user",
          "target_usernames" => [recipient.username],
          "message" => "Hello there",
        }.merge(parameters.stringify_keys),
        input_items:,
        node_settings:,
        &block
      )
    end

    def dm_user_ids(channel_id)
      Chat::Channel.find(channel_id).chatable.users.pluck(:id)
    end

    def expect_no_dm_side_effects(&block)
      expect(&block).to not_change { Chat::DirectMessageChannel.count }.and not_change {
              Chat::Message.count
            }
    end

    it "sends a direct message from the system user to the recipient" do
      hints = nil
      log = nil

      output =
        send_dm do |ctx|
          hints = hint_messages(ctx)
          log = log_messages(ctx)
        end

      json = output.first.first["json"]
      message = Chat::Message.find(json["message_id"])
      expect(json).to eq(
        "channel_id" => message.chat_channel_id,
        "message_id" => message.id,
        "message" => "Hello there",
        "username" => recipient.username,
      )
      expect(message).to have_attributes(message: "Hello there", user_id: Discourse.system_user.id)
      expect(dm_user_ids(json["channel_id"])).to contain_exactly(
        Discourse.system_user.id,
        recipient.id,
      )
      expect(hints).to be_empty
      expect(log).to eq(
        [
          sent_log(
            :user,
            message,
            sender: Discourse.system_user.username,
            username: recipient.username,
          ),
        ],
      )
    end

    it "doesn't leave a new direct message channel behind when the message is rejected" do
      SiteSetting.chat_maximum_message_length = 100

      expect {
        expect { send_dm(message: "x" * 101) }.to raise_error(
          DiscourseWorkflows::NodeError,
          /#{Regexp.escape(I18n.t("discourse_workflows.errors.send_chat_message.invalid_params", errors: ""))}/,
        )
      }.to not_change { Chat::DirectMessageChannel.count }.and not_change {
              Chat::UserChatChannelMembership.count
            }.and not_change { Chat::DirectMessage.count }
    end

    it "fails when the recipient username is blank" do
      expect { send_dm(target_usernames: " ") }.to raise_error(
        DiscourseWorkflows::NodeError,
        node_error(:recipient_blank),
      )
    end

    {
      "is staged" => [:recipient_staged, -> { recipient.update!(staged: true) }],
      "is suspended" => [
        :recipient_suspended,
        -> { recipient.update!(suspended_till: 1.day.from_now, suspended_at: Time.zone.now) },
      ],
      "is inactive" => [:recipient_inactive, -> { recipient.update!(active: false) }],
      "disabled chat" => [
        :recipient_chat_disabled,
        -> { recipient.user_option.update!(chat_enabled: false) },
      ],
      "is not allowed to chat" => [
        :recipient_cannot_chat,
        -> { SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:staff] },
      ],
    }.each do |condition, (error_key, setup)|
      it "fails when the recipient #{condition}" do
        instance_exec(&setup)

        expect { send_dm }.to raise_error(
          DiscourseWorkflows::NodeError,
          node_error(error_key, username: recipient.username),
        )
      end
    end

    it "fails when the sender is anonymous" do
      expect {
        send_dm(actor_username: DiscourseWorkflows::AnonymousActor::USERNAME)
      }.to raise_error(DiscourseWorkflows::NodeError, node_error(:sender_anonymous))
    end

    {
      "disabled chat" => [
        :sender_chat_disabled,
        -> { sender.user_option.update!(chat_enabled: false) },
      ],
      "is not allowed to chat" => [
        :sender_cannot_chat,
        -> do
          SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:trust_level_2]
          recipient.update!(trust_level: TrustLevel[2])
          Group.refresh_automatic_groups_for_user!(recipient)
        end,
      ],
    }.each do |condition, (error_key, setup)|
      it "fails when the sender #{condition}" do
        instance_exec(&setup)

        expect { send_dm(actor_username: sender.username) }.to raise_error(
          DiscourseWorkflows::NodeError,
          node_error(error_key, sender: sender.username),
        )
      end
    end

    {
      "is not allowed to send direct messages" => [
        :sender_cannot_create_dm,
        -> { SiteSetting.direct_message_enabled_groups = Group::AUTO_GROUPS[:staff] },
      ],
      "disabled personal messages" => [
        :sender_dms_disabled,
        -> { sender.user_option.update!(allow_private_messages: false) },
      ],
    }.each do |condition, (error_key, setup)|
      it "fails without creating a direct message when the sender #{condition}" do
        instance_exec(&setup)

        expect_no_dm_side_effects do
          expect { send_dm(actor_username: sender.username) }.to raise_error(
            DiscourseWorkflows::NodeError,
            node_error(error_key, sender: sender.username),
          )
        end
      end
    end

    it "doesn't hint at a bypass when the direct message is not delivered" do
      staff_sender = Fabricate(:moderator, refresh_auto_groups: true)
      recipient.user_option.update!(allow_private_messages: false)
      MutedUser.create!(user_id: staff_sender.id, muted_user_id: recipient.id)
      hints = nil

      output =
        send_dm(
          actor_username: staff_sender.username,
          node_settings: {
            "onError" => "continueRegularOutput",
          },
        ) { |ctx| hints = ctx.execution_hints }

      expect(output.first.sole).to include("error")
      expect(hints).to be_empty
    end

    context "with several recipients" do
      fab!(:carol) { Fabricate(:user, username: "carol", refresh_auto_groups: true) }
      fab!(:dave) { Fabricate(:user, username: "dave", refresh_auto_groups: true) }

      let(:usernames) { [recipient.username, carol.username, dave.username] }

      it "accepts comma-separated usernames, dropping blanks, duplicates and leading @" do
        output = send_dm(target_usernames: [" @bob, carol ,, BOB", "dave"])

        expect(output.first.map { |item| item["json"]["username"] }).to eq(usernames)
      end

      context "when sending individual direct messages" do
        it "fails the whole item without sending anything when one of the recipients can't receive it" do
          carol.update!(active: false)
          output = nil
          item_errors = nil

          expect_no_dm_side_effects do
            output =
              send_dm(
                target_usernames: usernames,
                node_settings: {
                  "onError" => "continueErrorOutput",
                },
              ) { |ctx| item_errors = ctx.metadata["item_errors"] }
          end

          expect(output.first.sole).to include(
            "error" =>
              include("message" => node_error(:recipient_inactive, username: carol.username)),
            "pairedItem" => {
              "item" => 0,
            },
          )
          expect(item_errors.size).to eq(1)
        end

        it "sends each recipient a separate direct message and fails only the refused ones" do
          MutedUser.create!(user_id: carol.id, muted_user_id: sender.id)
          item_errors = nil

          output =
            send_dm(
              target_usernames: usernames,
              actor_username: sender.username,
              node_settings: {
                "onError" => "continueErrorOutput",
              },
            ) { |ctx| item_errors = ctx.metadata["item_errors"] }

          items = output.first
          delivered_to_bob, refused, delivered_to_dave = items
          expect(items.map { |item| item["pairedItem"] }).to all(eq("item" => 0))
          expect(items.map { |item| item.key?("__failed") }).to eq([false, true, false])
          expect(
            [delivered_to_bob, delivered_to_dave].map { |item| item["json"]["username"] },
          ).to eq([recipient.username, dave.username])
          expect(refused).to include(
            "error" =>
              include(
                "message" =>
                  node_error(
                    :user_blocked,
                    sender: sender.username,
                    username: carol.username,
                    reason: I18n.t("chat.errors.not_accepting_dms", username: carol.username),
                  ),
              ),
          )
          expect(item_errors.size).to eq(1)
          expect(
            [delivered_to_bob, delivered_to_dave].map do |item|
              dm_user_ids(item["json"]["channel_id"])
            end,
          ).to match(
            [contain_exactly(sender.id, recipient.id), contain_exactly(sender.id, dave.id)],
          )
        end
      end

      context "when sending a group direct message" do
        it "sends one group direct message to all recipients and reuses it on re-runs" do
          log = nil
          output =
            send_dm(
              target_usernames: usernames,
              target: "group",
              actor_username: sender.username,
            ) { |ctx| log = log_messages(ctx) }

          item = output.first.sole
          channel_id = item["json"]["channel_id"]
          expect(item["json"]).to include("usernames" => usernames, "message" => "Hello there")
          expect(item["pairedItem"]).to eq("item" => 0)
          expect(Chat::Channel.find(channel_id).chatable).to be_group
          expect(dm_user_ids(channel_id)).to contain_exactly(
            sender.id,
            recipient.id,
            carol.id,
            dave.id,
          )
          expect(log).to eq(
            [
              sent_log(
                :group,
                Chat::Message.find(item["json"]["message_id"]),
                sender: sender.username,
                usernames: "'bob', 'carol', 'dave'",
              ),
            ],
          )

          rerun = nil
          expect {
            rerun =
              send_dm(
                target_usernames: usernames.reverse,
                target: "group",
                actor_username: sender.username,
                # Identical consecutive messages are rejected as duplicates.
                message: "Hello again",
              )
          }.not_to change { Chat::DirectMessageChannel.count }
          expect(rerun.first.sole["json"]["channel_id"]).to eq(channel_id)
          expect(Chat::Message.where(chat_channel_id: channel_id).count).to eq(2)
        end

        it "explains why a repeated identical message is rejected" do
          parameters = {
            target_usernames: usernames,
            target: "group",
            actor_username: sender.username,
          }
          send_dm(**parameters)

          expect { send_dm(**parameters) }.to raise_error(
            DiscourseWorkflows::NodeError,
            /\A#{Regexp.escape(I18n.t("discourse_workflows.errors.send_chat_message.invalid_params", errors: ""))}.+ \[item 0\]\z/,
          )
        end

        it "drops the sender from the recipients" do
          output =
            send_dm(
              target_usernames: [sender.username, *usernames],
              target: "group",
              actor_username: sender.username,
            )

          json = output.first.sole["json"]
          expect(json["usernames"]).to eq(usernames)
          expect(dm_user_ids(json["channel_id"])).to contain_exactly(
            sender.id,
            recipient.id,
            carol.id,
            dave.id,
          )
        end

        it "posts to the personal chat with a hint when the sender is the only recipient" do
          hints = nil
          output =
            send_dm(
              target_usernames: sender.username,
              target: "group",
              actor_username: sender.username,
            ) { |ctx| hints = ctx.execution_hints }

          json = output.first.sole["json"]
          expect(json["usernames"]).to eq([sender.username])
          expect(dm_user_ids(json["channel_id"])).to eq([sender.id])
          expect(hints).to eq(
            [
              {
                "message" => hint(:self_message, username: sender.username),
                "location" => "outputPane",
              },
            ],
          )
        end

        it "explains why the group is too large and creates nothing" do
          SiteSetting.chat_max_direct_message_users = 2

          expect_no_dm_side_effects do
            expect {
              send_dm(target_usernames: usernames, target: "group", actor_username: sender.username)
            }.to raise_error(
              DiscourseWorkflows::NodeError,
              node_error(
                :group_blocked,
                sender: sender.username,
                usernames: "'bob', 'carol', 'dave'",
                reason: I18n.t("chat.errors.over_chat_max_direct_message_users", count: 2),
              ),
            )
          end
        end

        it "hints at each recipient whose preferences a staff sender bypassed" do
          carol.user_option.update!(allow_private_messages: false)
          dave.user_option.update!(enable_allowed_pm_users: true)
          hints = nil

          send_dm(target_usernames: usernames, target: "group") { |ctx| hints = hint_messages(ctx) }

          expect(hints).to eq(
            [carol, dave].map do |user|
              hint(
                :preferences_bypassed,
                username: user.username,
                sender: Discourse.system_user.username,
              )
            end,
          )
        end
      end
    end
  end
end
