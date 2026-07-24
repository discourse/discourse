# frozen_string_literal: true

describe DiscoursePostEvent::TopicExtension do
  before do
    freeze_time
    Jobs.run_immediately!
    SiteSetting.calendar_enabled = true
    SiteSetting.discourse_post_event_enabled = true
  end

  fab!(:user) { Fabricate(:user, admin: true, refresh_auto_groups: true) }

  let(:event_topic) { Fabricate(:topic, user:, created_at: 2.days.ago) }
  let(:event_op) { Fabricate(:post, topic: event_topic, user:, created_at: 2.days.ago) }
  let!(:event) { Fabricate(:event, post: event_op) }

  let(:plain_topic) { Fabricate(:topic, user:, created_at: 2.days.ago) }
  let!(:plain_op) { Fabricate(:post, topic: plain_topic, user:, created_at: 2.days.ago) }

  let(:source_topic) { Fabricate(:topic, user:) }

  def move(from:, post_ids:, into:, chronological_order:)
    from.move_posts(user, post_ids, destination_topic_id: into.id, chronological_order:)
  end

  def expect_block(&block)
    expect(&block).to raise_error(
      ActiveRecord::RecordNotSaved,
      I18n.t("discourse_post_event.errors.models.event.must_be_in_first_post"),
    )
  end

  describe "#move_posts" do
    context "when destination has an event and incoming does not" do
      it "blocks chronological merge with an older incoming post (would displace the event)" do
        older = Fabricate(:post, topic: source_topic, user:, created_at: 5.days.ago)

        expect_block do
          move(
            from: source_topic,
            post_ids: [older.id],
            into: event_topic,
            chronological_order: true,
          )
        end
        expect(event_op.reload.post_number).to eq(1)
      end

      it "allows chronological merge with a newer incoming post" do
        newer = Fabricate(:post, topic: source_topic, user:, created_at: 1.hour.ago)

        expect {
          move(
            from: source_topic,
            post_ids: [newer.id],
            into: event_topic,
            chronological_order: true,
          )
        }.not_to raise_error
        expect(event_op.reload.post_number).to eq(1)
      end

      it "allows sequential merge regardless of created_at" do
        older = Fabricate(:post, topic: source_topic, user:, created_at: 5.days.ago)

        expect {
          move(
            from: source_topic,
            post_ids: [older.id],
            into: event_topic,
            chronological_order: false,
          )
        }.not_to raise_error
        expect(event_op.reload.post_number).to eq(1)
      end
    end

    context "when incoming has an event and destination does not" do
      let(:incoming_topic) { Fabricate(:topic, user:) }
      let(:incoming_event_op) do
        Fabricate(:post, topic: incoming_topic, user:, created_at: 5.days.ago)
      end
      let!(:incoming_event) { Fabricate(:event, post: incoming_event_op) }

      it "allows chronological merge when the incoming event is the oldest post" do
        expect {
          move(
            from: incoming_topic,
            post_ids: [incoming_event_op.id],
            into: plain_topic,
            chronological_order: true,
          )
        }.not_to raise_error
      end

      it "blocks chronological merge when the incoming event is newer than the destination OP" do
        newer_topic = Fabricate(:topic, user:)
        newer_event_op = Fabricate(:post, topic: newer_topic, user:, created_at: 1.hour.ago)
        Fabricate(:event, post: newer_event_op)

        expect_block do
          move(
            from: newer_topic,
            post_ids: [newer_event_op.id],
            into: plain_topic,
            chronological_order: true,
          )
        end
      end

      it "blocks sequential merge (incoming event would land in a non-OP slot)" do
        expect_block do
          move(
            from: incoming_topic,
            post_ids: [incoming_event_op.id],
            into: plain_topic,
            chronological_order: false,
          )
        end
      end
    end

    context "when both destination and incoming have an event" do
      let(:incoming_topic) { Fabricate(:topic, user:) }
      let(:incoming_event_op) do
        Fabricate(:post, topic: incoming_topic, user:, created_at: 1.hour.ago)
      end
      let!(:incoming_event) { Fabricate(:event, post: incoming_event_op) }

      it "blocks the merge whether chronological or sequential" do
        expect_block do
          move(
            from: incoming_topic,
            post_ids: [incoming_event_op.id],
            into: event_topic,
            chronological_order: true,
          )
        end

        expect_block do
          move(
            from: incoming_topic,
            post_ids: [incoming_event_op.id],
            into: event_topic,
            chronological_order: false,
          )
        end
      end
    end

    context "with unrelated merges" do
      it "allows any merge when neither topic has an event" do
        other = Fabricate(:post, topic: source_topic, user:, created_at: 5.days.ago)

        expect {
          move(
            from: source_topic,
            post_ids: [other.id],
            into: plain_topic,
            chronological_order: true,
          )
        }.not_to raise_error
      end

      it "does not block when discourse_post_event is disabled" do
        SiteSetting.discourse_post_event_enabled = false
        older = Fabricate(:post, topic: source_topic, user:, created_at: 5.days.ago)

        expect {
          move(
            from: source_topic,
            post_ids: [older.id],
            into: event_topic,
            chronological_order: true,
          )
        }.not_to raise_error
      end
    end
  end
end
