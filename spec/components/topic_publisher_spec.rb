# frozen_string_literal: true

require 'topic_publisher'
require 'rails_helper'

describe TopicPublisher do

  context "shared drafts" do
    fab!(:shared_drafts_category) { Fabricate(:category) }
    fab!(:category) { Fabricate(:category) }

    before do
      SiteSetting.shared_drafts_category = shared_drafts_category.id
    end

    context "publishing" do
      fab!(:topic) { Fabricate(:topic, category: shared_drafts_category, visible: false) }
      fab!(:shared_draft) { Fabricate(:shared_draft, topic: topic, category: category) }
      fab!(:moderator) { Fabricate(:moderator) }
      fab!(:op) { Fabricate(:post, topic: topic) }

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
          expect(topic.created_at).to eq(published_at)
          expect(topic.updated_at).to eq(published_at)
          expect(topic.shared_draft).to be_blank

          expect(UserHistory.where(
            acting_user_id: moderator.id,
            action: UserHistory.actions[:topic_published]
          )).to be_present

          op.reload

          # Should delete any edits on the OP
          expect(op.revisions.size).to eq(0)
          expect(op.version).to eq(1)
          expect(op.public_version).to eq(1)
          expect(op.created_at).to eq(published_at)
          expect(op.updated_at).to eq(published_at)
          expect(op.last_version_at).to eq(published_at)
        end
      end
    end

  end

end
