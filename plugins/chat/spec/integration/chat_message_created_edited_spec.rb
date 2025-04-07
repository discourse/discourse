# frozen_string_literal: true

describe "ChatMessageCreatedEdited" do
  before { SiteSetting.discourse_automation_enabled = true }

  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:automation) { Fabricate(:automation, trigger: "chat_message_created_edited") }
  fab!(:channel) { Fabricate(:chat_channel) }

  def update_message(message, content)
    Chat::UpdateMessage.call(
      guardian: Guardian.new(Discourse.system_user),
      params: {
        message_id: message.id,
        message: content,
      },
    )
  end

  context "when a chat message is created" do
    it "fires the trigger" do
      list =
        capture_contexts do
          Fabricate(:chat_message, user: user, chat_channel: channel, use_service: true)
        end

      expect(list.length).to eq(1)
      expect(list[0]["kind"]).to eq("chat_message_created_edited")
      expect(list[0]["action"].to_s).to eq("create")
    end

    context "when action_type is set to edited" do
      before do
        automation.upsert_field!("action_type", "choices", { value: "edited" }, target: "trigger")
      end

      it "doesn't fire the trigger for create" do
        list =
          capture_contexts do
            Fabricate(:chat_message, user: user, chat_channel: channel, use_service: true)
          end
        expect(list.length).to eq(0)
      end
    end
  end

  context "when a chat message is edited" do
    fab!(:chat_message) { Fabricate(:chat_message, user: user, chat_channel: channel) }

    it "fires the trigger" do
      list = capture_contexts { update_message(chat_message, "edited message") }

      expect(list.length).to eq(1)
      expect(list[0]["kind"]).to eq("chat_message_created_edited")
      expect(list[0]["action"].to_s).to eq("edit")
    end

    context "when action_type is set to created" do
      before do
        automation.upsert_field!("action_type", "choices", { value: "created" }, target: "trigger")
      end

      it "doesn't fire the trigger for edit" do
        list = capture_contexts { update_message(chat_message, "edited message") }
        expect(list.length).to eq(0)
      end
    end
  end

  context "when restricted_channels is set" do
    fab!(:other_channel) { Fabricate(:chat_channel) }

    before do
      automation.upsert_field!(
        "restricted_channels",
        "chat_channels",
        { value: [channel.id] },
        target: "trigger",
      )
    end

    it "fires the trigger for the selected channel" do
      list =
        capture_contexts do
          Fabricate(:chat_message, user: user, chat_channel: channel, use_service: true)
        end
      expect(list.length).to eq(1)
    end

    it "doesn't fire the trigger for other channels" do
      list = capture_contexts { Fabricate(:chat_message, user: user, chat_channel: other_channel) }
      expect(list.length).to eq(0)
    end
  end

  context "when restricted_groups is set" do
    fab!(:group)

    before do
      automation.upsert_field!(
        "restricted_groups",
        "groups",
        { value: [group.id] },
        target: "trigger",
      )
    end

    context "when user is a member of the group" do
      before { group.add(user) }

      it "fires the trigger" do
        list =
          capture_contexts do
            Fabricate(:chat_message, user: user, chat_channel: channel, use_service: true)
          end
        expect(list.length).to eq(1)
      end
    end

    context "when user is not a member of the group" do
      it "doesn't fire the trigger" do
        list = capture_contexts { Fabricate(:chat_message, user: user, chat_channel: channel) }
        expect(list.length).to eq(0)
      end
    end
  end

  context "with bot users" do
    it "doesn't fire the trigger for bot messages" do
      list =
        capture_contexts do
          Fabricate(:chat_message, user: Discourse.system_user, chat_channel: channel)
        end
      expect(list.length).to eq(0)
    end
  end
end
