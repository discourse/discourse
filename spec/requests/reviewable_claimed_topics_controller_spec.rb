# frozen_string_literal: true

RSpec.describe ReviewableClaimedTopicsController do
  fab!(:moderator) { Fabricate(:moderator) }

  fab!(:topic) { Fabricate(:topic) }
  fab!(:reviewable) { Fabricate(:reviewable_flagged_post, topic: topic) }

  describe "#create" do
    let(:params) { { reviewable_claimed_topic: { topic_id: topic.id } } }

    it "requires user to be logged in" do
      post "/reviewable_claimed_topics.json", params: params

      expect(response.status).to eq(403)
    end

    context "when logged in" do
      before do
        SiteSetting.reviewable_claiming = "optional"
        sign_in(moderator)
      end

      it "works" do
        messages =
          MessageBus.track_publish("/reviewable_claimed") do
            post "/reviewable_claimed_topics.json", params: params
            expect(response.status).to eq(200)
          end

        expect(
          ReviewableClaimedTopic.where(user_id: moderator.id, topic_id: topic.id).exists?,
        ).to eq(true)
        expect(
          topic
            .reviewables
            .first
            .history
            .where(reviewable_history_type: ReviewableHistory.types[:claimed])
            .size,
        ).to eq(1)
        expect(messages.size).to eq(1)

        message = messages[0]

        expect(message.data[:topic_id]).to eq(topic.id)
        expect(message.data[:user][:id]).to eq(moderator.id)
        expect(message.group_ids).to contain_exactly(Group::AUTO_GROUPS[:staff])
      end

      it "publishes reviewable claimed changes to the category moderators of the topic's category" do
        SiteSetting.enable_category_group_moderation = true
        SiteSetting.reviewable_claiming = "optional"

        group = Fabricate(:group)
        topic.category.update!(reviewable_by_group: group)

        messages =
          MessageBus.track_publish("/reviewable_claimed") do
            post "/reviewable_claimed_topics.json", params: params
            expect(response.status).to eq(200)
          end

        expect(messages.size).to eq(1)

        message = messages[0]

        expect(message.data[:topic_id]).to eq(topic.id)
        expect(message.data[:user][:id]).to eq(moderator.id)
        expect(message.group_ids).to contain_exactly(Group::AUTO_GROUPS[:staff], group.id)
      end

      it "works with deleted topics" do
        first_post = topic.first_post || Fabricate(:post, topic: topic)
        PostDestroyer.new(Discourse.system_user, first_post).destroy

        post "/reviewable_claimed_topics.json", params: params

        expect(response.status).to eq(200)
        expect(
          ReviewableClaimedTopic.where(user_id: moderator.id, topic_id: topic.id).exists?,
        ).to eq(true)
      end

      it "raises an error if user cannot claim the topic" do
        SiteSetting.reviewable_claiming = "disabled"
        post "/reviewable_claimed_topics.json", params: params

        expect(response.status).to eq(403)
      end

      it "raises an error if topic is already claimed" do
        post "/reviewable_claimed_topics.json", params: params
        expect(
          ReviewableClaimedTopic.where(user_id: moderator.id, topic_id: topic.id).exists?,
        ).to eq(true)

        post "/reviewable_claimed_topics.json", params: params
        expect(response.status).to eq(409)
      end

      it "queues a sidekiq job to refresh reviewable counts for users who can see the reviewable" do
        SiteSetting.navigation_menu = "sidebar"
        SiteSetting.enable_category_group_moderation = true

        not_notified = Fabricate(:user)

        group = Fabricate(:group)
        topic.category.update!(reviewable_by_group: group)
        reviewable.update!(reviewable_by_group: group)

        notified = Fabricate(:user)
        group.add(notified)

        expect_enqueued_with(
          job: :refresh_users_reviewable_counts,
          args: {
            group_ids: [Group::AUTO_GROUPS[:staff], group.id],
          },
        ) do
          post "/reviewable_claimed_topics.json", params: params
          expect(response.status).to eq(200)
        end
      end
    end
  end

  describe "#destroy" do
    fab!(:claimed) { Fabricate(:reviewable_claimed_topic, topic: topic) }

    before { sign_in(moderator) }

    it "works" do
      SiteSetting.reviewable_claiming = "optional"

      messages =
        MessageBus.track_publish("/reviewable_claimed") do
          delete "/reviewable_claimed_topics/#{claimed.topic_id}.json"
          expect(response.status).to eq(200)
        end

      expect(ReviewableClaimedTopic.where(topic_id: claimed.topic_id).exists?).to eq(false)
      expect(
        topic
          .reviewables
          .first
          .history
          .where(reviewable_history_type: ReviewableHistory.types[:unclaimed])
          .size,
      ).to eq(1)
      expect(messages.size).to eq(1)

      message = messages[0]

      expect(message.data[:topic_id]).to eq(topic.id)
      expect(message.data[:user]).to eq(nil)
      expect(message.group_ids).to contain_exactly(Group::AUTO_GROUPS[:staff])
    end

    it "works with deleted topics" do
      SiteSetting.reviewable_claiming = "optional"
      first_post = topic.first_post || Fabricate(:post, topic: topic)
      PostDestroyer.new(Discourse.system_user, first_post).destroy

      delete "/reviewable_claimed_topics/#{claimed.topic_id}.json"

      expect(response.status).to eq(200)
      expect(ReviewableClaimedTopic.where(user_id: moderator.id, topic_id: topic.id).exists?).to eq(
        false,
      )
    end

    it "raises an error if topic is missing" do
      delete "/reviewable_claimed_topics/111111111.json"

      expect(response.status).to eq(404)
    end

    it "raises an error if user cannot claim the topic" do
      delete "/reviewable_claimed_topics/#{claimed.topic_id}.json"

      expect(response.status).to eq(403)
    end

    it "queues a sidekiq job to refresh reviewable counts for users who can see the reviewable" do
      SiteSetting.reviewable_claiming = "optional"
      SiteSetting.navigation_menu = "sidebar"
      SiteSetting.enable_category_group_moderation = true

      not_notified = Fabricate(:user)

      group = Fabricate(:group)
      topic.category.update!(reviewable_by_group: group)
      reviewable.update!(reviewable_by_group: group)

      notified = Fabricate(:user)
      group.add(notified)

      expect_enqueued_with(
        job: :refresh_users_reviewable_counts,
        args: {
          group_ids: [Group::AUTO_GROUPS[:staff], group.id],
        },
      ) do
        delete "/reviewable_claimed_topics/#{claimed.topic_id}.json"
        expect(response.status).to eq(200)
      end
    end
  end
end
