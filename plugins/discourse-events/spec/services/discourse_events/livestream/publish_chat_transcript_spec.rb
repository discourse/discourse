# frozen_string_literal: true

RSpec.describe DiscourseEvents::Livestream::PublishChatTranscript do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:event_date_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:) }

    fab!(:group)
    fab!(:category) { Fabricate(:private_category, group:) }
    fab!(:starts_at) { 2.hours.ago.beginning_of_minute }
    fab!(:ends_at) { 1.hour.ago.beginning_of_minute }
    # The raw carries the event too: editing the post re-syncs the event from it.
    fab!(:event_post) do
      Fabricate(
        :post,
        user: Fabricate(:admin, refresh_auto_groups: true),
        topic: Fabricate(:topic, category:),
        raw: <<~RAW,
        [event start="#{starts_at.strftime("%Y-%m-%d %H:%M")}" end="#{ends_at.strftime("%Y-%m-%d %H:%M")}" status="public" timezone="UTC" livestream="true" location="https://www.youtube.com/live/abc123"]
        [/event]

        Come along!
      RAW
      )
    end
    fab!(:event) do
      Fabricate(
        :event,
        post: event_post,
        livestream: true,
        location: "https://www.youtube.com/live/abc123",
        timezone: "UTC",
        original_starts_at: starts_at,
        original_ends_at: ends_at,
        raw_invitees: ["trust_level_0"],
        description: "",
      )
    end
    fab!(:viewer, :user)

    let(:params) { { event_date_id: } }
    let(:event_date_id) { event.event_dates.first.id }
    let(:topic) { event.post.topic }
    let(:topic_chat_channel) { DiscourseEvents::Livestream::TopicChatChannel.find_by(topic:) }
    let(:chat_channel) { topic_chat_channel.chat_channel }

    before do
      SiteSetting.chat_enabled = true
      SiteSetting.discourse_events_enabled = true
      SiteSetting.discourse_post_event_enabled = true
      SiteSetting.chat_allowed_groups = group.id.to_s
      DiscourseEvents::Livestream.handle_topic_chat_channel_creation(topic)
    end

    context "when contract is invalid" do
      let(:event_date_id) { nil }

      it { is_expected.to fail_a_contract }
    end

    context "when chat is disabled" do
      before { SiteSetting.chat_enabled = false }

      it { is_expected.to fail_a_policy(:chat_enabled) }
    end

    context "when the event date does not exist" do
      let(:event_date_id) { 0 }

      it { is_expected.to fail_to_find_a_model(:event_date) }
    end

    context "when the event is not a livestream" do
      before { event.update_columns(livestream: false) }

      it { is_expected.to fail_to_find_a_model(:event) }
    end

    context "when the topic has no livestream chat channel" do
      before { topic_chat_channel.destroy! }

      it { is_expected.to fail_to_find_a_model(:topic_chat_channel) }
    end

    context "without any chat messages" do
      it { is_expected.to run_successfully }

      it "leaves the topic alone" do
        expect { result }.not_to change { [topic.posts.count, event_post.reload.raw] }
      end

      it "closes the chat channel" do
        expect { result }.to change { chat_channel.reload.status }.to("closed")
      end
    end

    context "with chat messages" do
      let!(:messages) do
        [
          Fabricate(:chat_message, chat_channel:, user: viewer, message: "Hello stream"),
          Fabricate(:chat_message, chat_channel:, user: viewer, message: "Great talk"),
        ]
      end

      it { is_expected.to run_successfully }

      it "appends the transcript to the event post" do
        result

        expect(event_post.reload.raw).to start_with(event_post.raw.rstrip)
        expect(event_post.raw).to include("Chat transcript", "Hello stream", "Great talk")
        expect(event_post.last_editor_id).to eq(Discourse::SYSTEM_USER_ID)
      end

      it "does not reply to the topic" do
        expect { result }.not_to change { topic.posts.count }
      end

      it "keeps the event as it was" do
        expect { result }.not_to change { event.reload.attributes.except("updated_at") }
      end

      it "leaves out the pinned reference message" do
        reference_message = Chat::Message.find(topic_chat_channel.reference_message_id)
        result

        expect(event_post.reload.raw).not_to include(reference_message.message)
      end

      it "records how far the chat has been transcribed" do
        expect { result }.to change { topic_chat_channel.reload.last_transcribed_message_id }.to(
          messages.last.id,
        )
      end

      it "only transcribes messages sent since the previous transcript" do
        topic_chat_channel.update!(last_transcribed_message_id: messages.first.id)
        result

        expect(event_post.reload.raw).to include("Great talk")
        expect(event_post.raw).not_to include("Hello stream")
      end

      it "does not notify anyone or bump the topic" do
        expect_not_enqueued_with(job: :post_alert) { result }
        expect(topic.reload.bumped_at).to eq_time(topic.bumped_at)
      end

      it "keeps the event post within the length limit" do
        SiteSetting.max_post_length = event_post.raw.length + 120
        result

        expect(event_post.reload.raw.length).to be <= SiteSetting.max_post_length
        expect(event_post.raw).to include("earlier message")
      end

      context "when the event is recurring" do
        before { event.update_columns(recurrence: "every_week") }

        it "replies with a dated transcript instead" do
          expect { result }.to change { topic.posts.count }.by(1)

          reply = topic.posts.last
          expect(reply.user).to eq(Discourse.system_user)
          expect(reply.raw).to start_with("Chat transcript for [date=")
          expect(reply.raw).to include("Hello stream", "Great talk")
          expect(event_post.reload.raw).not_to include("Hello stream")
        end

        it "does not notify anyone or bump the topic" do
          expect_not_enqueued_with(job: :post_alert) { result }
          expect(topic.reload.bumped_at).to eq_time(topic.bumped_at)
        end
      end

      context "when some topic readers could not read the chat" do
        before { SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:admins].to_s }

        it { is_expected.to run_successfully }

        it "keeps the chat out of the topic" do
          expect { result }.not_to change { [topic.posts.count, event_post.reload.raw] }
        end

        it "still closes the chat channel" do
          expect { result }.to change { chat_channel.reload.status }.to("closed")
        end
      end
    end

    context "when a recurring livestream has more occurrences" do
      before { event.update_columns(recurrence: "every_week") }

      it { is_expected.to run_successfully }

      it "keeps the chat channel open for the next occurrence" do
        expect { result }.not_to change { chat_channel.reload.status }
      end
    end
  end
end
