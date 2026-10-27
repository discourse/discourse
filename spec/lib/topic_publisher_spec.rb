# frozen_string_literal: true

require "topic_publisher"

RSpec.describe TopicPublisher do
  describe "shared drafts" do
    fab!(:shared_drafts_category, :category)
    fab!(:category)

    before { SiteSetting.shared_drafts_category = shared_drafts_category.id }

    context "when publishing" do
      fab!(:topic) { Fabricate(:topic, category: shared_drafts_category, visible: false) }
      fab!(:shared_draft) { Fabricate(:shared_draft, topic: topic, category: category) }
      fab!(:moderator)
      fab!(:op) { Fabricate(:post, topic: topic) }
      fab!(:user)
      fab!(:tag)

      before do
        # Create a revision
        op.set_owner(Fabricate(:coding_horror), Discourse.system_user)
        op.reload
      end

      it "publishes the topic" do
        published_at = 1.hour.from_now.change(usec: 0)
        freeze_time(published_at) do
          TopicPublisher.new(topic, moderator, shared_draft.category_id).publish!

          topic.reload
          expect(topic.category).to eq(category)
          expect(topic).to be_visible
          expect(topic.created_at).to eq_time(published_at)
          expect(topic.updated_at).to eq_time(published_at)
          expect(topic.shared_draft).to be_blank

          expect(
            UserHistory.where(
              acting_user_id: moderator.id,
              action: UserHistory.actions[:topic_published],
            ),
          ).to be_present

          op.reload

          # Should delete any edits on the OP
          expect(op.revisions.size).to eq(0)
          expect(op.version).to eq(1)
          expect(op.public_version).to eq(1)
          expect(op.created_at).to eq_time(published_at)
          expect(op.updated_at).to eq_time(published_at)
          expect(op.last_version_at).to eq_time(published_at)
        end
      end

      it "triggers topic_published with the publishing user" do
        freeze_time

        event =
          DiscourseEvent.track(:topic_published) do
            TopicPublisher.new(topic, moderator, shared_draft.category_id).publish!
          end

        expect(event[:params]).to eq([topic, Time.zone.now, { acting_user: moderator }])
      end

      it "triggers topic_converted_to_public_topic after topic_published for a personal message" do
        topic.update_columns(archetype: Archetype.private_message, category_id: nil)
        topic.topic_allowed_users.create!(user: moderator)

        events =
          DiscourseEvent.track_events do
            TopicPublisher.new(topic, moderator, shared_draft.category_id).publish!
          end

        expect(topic.reload).to have_attributes(archetype: Archetype.default, category: category)
        conversion = events.find { |event| event[:event_name] == :topic_converted_to_public_topic }
        expect(conversion[:params]).to eq([topic, { acting_user: moderator }])
        expect(
          events.map { |event| event[:event_name] } &
            %i[topic_published topic_converted_to_public_topic],
        ).to eq(%i[topic_published topic_converted_to_public_topic])
      end

      it "notifies users watching the tag" do
        Jobs.run_immediately!

        TagUser.create!(
          user_id: user.id,
          tag_id: tag.id,
          notification_level: NotificationLevels.topic_levels[:watching],
        )

        topic.update!(tags: [tag])

        expect {
          TopicPublisher.new(topic, moderator, shared_draft.category_id).publish!
        }.to change { Notification.count }.by(1)

        topic.reload
        expect(topic.tags).to contain_exactly(tag)
      end
    end
  end
end
