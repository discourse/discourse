# frozen_string_literal: true

require "topic_publisher"

RSpec.describe TopicPublisher do
  describe "shared drafts" do
    fab!(:shared_drafts_category) { Fabricate(:category) }
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

      it "will publish the topic properly" do
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

      it "will notify users watching tag" do
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
