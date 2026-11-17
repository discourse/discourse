# frozen_string_literal: true

RSpec.describe "Topic tracking state MessageBus audiences" do
  subject(:message_types) do
    sign_in(viewer)
    post "/message-bus/#{SecureRandom.hex}/poll?dlp=t", params: { channel => 0 }
    response
      .parsed_body
      .select { it["channel"] == channel && it.dig("data", "topic_id") == topic.id }
      .map { it.dig("data", "message_type") }
  end

  fab!(:admin)
  fab!(:moderator) { Fabricate(:moderator, last_seen_at: 1.minute.ago) }
  fab!(:member) { Fabricate(:user, last_seen_at: 1.minute.ago) }
  fab!(:outsider) { Fabricate(:user, last_seen_at: 1.minute.ago) }
  fab!(:muter) { Fabricate(:user, last_seen_at: 1.minute.ago) }
  fab!(:group)
  fab!(:tag)

  let(:category) { Fabricate(:private_category, group:) }
  let(:topic) { Fabricate(:topic, category:, tags: [tag]) }
  let(:whisper) { false }
  let(:whispers_allowed_groups) { Group::AUTO_GROUPS[:staff].to_s }

  before do
    SiteSetting.tagging_enabled = true
    SiteSetting.whispers_allowed_groups = whispers_allowed_groups
    group.add(member)
    Fabricate(:post, topic:)

    [member, outsider, moderator].each do
      TagUser.change(it.id, tag.id, TagUser.notification_levels[:watching])
      TopicUser.change(it.id, topic.id, notification_level: NotificationLevels.all[:tracking])
    end
    TopicUser.change(muter.id, topic.id, notification_level: NotificationLevels.all[:muted])

    sign_in(admin)
    Jobs.with_immediate_jobs do
      post "/posts.json", params: { topic_id: topic.id, raw: "A reply to the topic", whisper: }
    end
  end

  describe "/latest" do
    let(:channel) { "/latest" }

    context "when the viewer is a tag watcher who can see the topic" do
      let(:viewer) { member }

      it "sends the activity of the topic" do
        expect(message_types).to include("unmuted")
      end
    end

    context "when the viewer is a tag watcher who cannot see the topic" do
      let(:viewer) { outsider }

      it "hides the activity of the topic" do
        expect(message_types).not_to include("unmuted")
      end
    end

    context "when the viewer muted the topic before losing access" do
      let(:viewer) { muter }

      it "hides the activity of the topic" do
        expect(message_types).not_to include("muted")
      end
    end

    context "when no group can see the category" do
      let(:category) { Fabricate(:category, read_restricted: true) }
      let(:viewer) { member }

      it "hides the activity of the topic" do
        expect(message_types).not_to include("unmuted")
      end
    end

    context "when the reply is a whisper in a public category" do
      let(:whisper) { true }
      let(:category) { Fabricate(:category) }

      context "when the viewer cannot see whispers" do
        let(:viewer) { outsider }

        it "hides the activity of the topic" do
          expect(message_types).not_to include("unmuted")
        end
      end

      context "when the viewer can see whispers" do
        let(:viewer) { moderator }

        it "sends the activity of the topic" do
          expect(message_types).to include("unmuted")
        end
      end

      context "when the viewer is a moderator outside the whisper groups" do
        let(:whispers_allowed_groups) { Fabricate(:group).id.to_s }
        let(:viewer) { moderator }

        it "hides the activity of the topic" do
          expect(message_types).not_to include("unmuted")
        end
      end
    end
  end

  describe "/unread" do
    let(:channel) { "/unread" }

    context "when the viewer is a tracker who can see the topic" do
      let(:viewer) { member }

      it "sends the unread state" do
        expect(message_types).to include("unread")
      end
    end

    context "when the viewer is a tracker who cannot see the topic" do
      let(:viewer) { outsider }

      it "hides the unread state" do
        expect(message_types).not_to include("unread")
      end
    end

    context "when no group can see the category" do
      let(:category) { Fabricate(:category, read_restricted: true) }
      let(:viewer) { member }

      it "hides the unread state" do
        expect(message_types).not_to include("unread")
      end
    end

    context "when the reply is a whisper" do
      let(:whisper) { true }

      context "when the viewer is a moderator who cannot see the category" do
        let(:viewer) { moderator }

        it "hides the unread state" do
          expect(message_types).not_to include("unread")
        end
      end

      context "when the category is public" do
        let(:category) { Fabricate(:category) }
        let(:viewer) { moderator }

        context "when the viewer is a moderator who can see whispers" do
          it "sends the unread state" do
            expect(message_types).to include("unread")
          end
        end

        context "when the viewer is a moderator outside the whisper groups" do
          let(:whispers_allowed_groups) { Fabricate(:group).id.to_s }

          it "hides the unread state" do
            expect(message_types).not_to include("unread")
          end
        end
      end
    end
  end
end
