# frozen_string_literal: true

RSpec.describe ReviewableClaimedTopicsController do
  fab!(:moderator)

  fab!(:topic)
  fab!(:automatic_topic, :topic)
  fab!(:reviewable) { Fabricate(:reviewable_flagged_post, topic: topic) }
  fab!(:automatic_reviewable) { Fabricate(:reviewable_flagged_post, topic: automatic_topic) }

  describe "#create" do
    let(:params) { { reviewable_claimed_topic: { topic_id: topic.id } } }

    it "requires user to be logged in" do
      post "/reviewable_claimed_topics.json", params: params

      expect(response.status).to eq(403)
    end

    context "when logged in as a category group moderator" do
      fab!(:mod_group, :group)
      fab!(:cat_mod_user, :user)
      fab!(:private_category) { Fabricate(:private_category, group: Fabricate(:group)) }
      fab!(:private_topic) { Fabricate(:topic, category: private_category) }

      before do
        SiteSetting.enable_category_group_moderation = true
        SiteSetting.reviewable_claiming = "optional"
        Fabricate(:category_moderation_group, category: private_category, group: mod_group)
        mod_group.add(cat_mod_user)
        sign_in(cat_mod_user)
      end

      it "prevents claiming a topic the user cannot see" do
        post "/reviewable_claimed_topics.json",
             params: {
               reviewable_claimed_topic: {
                 topic_id: private_topic.id,
               },
             }

        expect(response.status).to eq(403)
        expect(
          ReviewableClaimedTopic.where(
            user_id: cat_mod_user.id,
            topic_id: private_topic.id,
          ).exists?,
        ).to eq(false)
      end

      it "prevents claiming a topic the user cannot see with automatic param" do
        post "/reviewable_claimed_topics.json",
             params: {
               reviewable_claimed_topic: {
                 topic_id: private_topic.id,
                 automatic: "true",
               },
             }

        expect(response.status).to eq(403)
        expect(
          ReviewableClaimedTopic.where(
            user_id: cat_mod_user.id,
            topic_id: private_topic.id,
          ).exists?,
        ).to eq(false)
      end

      it "prevents claiming a deleted topic the user cannot see" do
        first_post = private_topic.first_post || Fabricate(:post, topic: private_topic)
        PostDestroyer.new(Discourse.system_user, first_post, context: "Automated testing").destroy

        post "/reviewable_claimed_topics.json",
             params: {
               reviewable_claimed_topic: {
                 topic_id: private_topic.id,
               },
             }

        expect(response.status).to eq(403)
        expect(
          ReviewableClaimedTopic.where(
            user_id: cat_mod_user.id,
            topic_id: private_topic.id,
          ).exists?,
        ).to eq(false)
      end

      it "allows claiming a topic the user can see" do
        private_category.set_permissions(mod_group => :full)
        private_category.save!

        post "/reviewable_claimed_topics.json",
             params: {
               reviewable_claimed_topic: {
                 topic_id: private_topic.id,
               },
             }

        expect(response.status).to eq(200)
        expect(
          ReviewableClaimedTopic.where(
            user_id: cat_mod_user.id,
            topic_id: private_topic.id,
          ).exists?,
        ).to eq(true)
      end
    end

    context "when logged in as a moderator" do
      before do
        SiteSetting.reviewable_claiming = "optional"
        sign_in(moderator)
      end

      it "claims the topic, logs it, and notifies staff" do
        messages =
          MessageBus.track_publish("/reviewable_claimed") do
            post "/reviewable_claimed_topics.json", params: params
            expect(response.status).to eq(200)
          end

        expect(
          ReviewableClaimedTopic.where(user_id: moderator.id, topic_id: topic.id).exists?,
        ).to eq(true)
        expect(reviewable.history.claimed.size).to eq(1)
        expect(messages.size).to eq(1)

        message = messages[0]

        expect(message.data[:topic_id]).to eq(topic.id)
        expect(message.data[:user][:id]).to eq(moderator.id)
        expect(message.data[:claimed]).to be true
        expect(message.group_ids).to contain_exactly(Group::AUTO_GROUPS[:staff])
      end

      it "publishes reviewable claimed changes to the category moderators of the topic's category" do
        SiteSetting.enable_category_group_moderation = true

        group = Fabricate(:group)
        Fabricate(:category_moderation_group, category: topic.category, group:)

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
        PostDestroyer.new(Discourse.system_user, first_post, context: "Automated testing").destroy

        post "/reviewable_claimed_topics.json", params: params

        expect(response.status).to eq(200)
        expect(
          ReviewableClaimedTopic.where(user_id: moderator.id, topic_id: topic.id).exists?,
        ).to eq(true)
      end

      it "returns 403 when claiming is disabled" do
        SiteSetting.reviewable_claiming = "disabled"
        post "/reviewable_claimed_topics.json", params: params

        expect(response.status).to eq(403)
      end

      it "allows claiming when automatic param is present, without logging history" do
        SiteSetting.reviewable_claiming = "disabled"
        params[:reviewable_claimed_topic][:topic_id] = automatic_topic.id
        params[:reviewable_claimed_topic][:automatic] = "true"

        post "/reviewable_claimed_topics.json", params: params

        expect(response.status).to eq(200)
        expect(
          ReviewableClaimedTopic.where(user_id: moderator.id, topic_id: automatic_topic.id).exists?,
        ).to eq(true)
        expect(automatic_reviewable.history.claimed).to be_empty
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
        SiteSetting.enable_category_group_moderation = true

        group = Fabricate(:group)
        Fabricate(:category_moderation_group, category: topic.category, group:)

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
    fab!(:automatic_claimed) do
      Fabricate(:reviewable_claimed_topic, topic: automatic_topic, automatic: true)
    end

    context "when logged in as a regular user" do
      fab!(:user)

      before { sign_in(user) }

      it "returns 404 for both existing and non-existing topics to prevent enumeration" do
        SiteSetting.reviewable_claiming = "optional"

        delete "/reviewable_claimed_topics/#{topic.id}.json"
        existing_topic_status = response.status

        delete "/reviewable_claimed_topics/#{topic.id + 1000}.json"
        non_existing_topic_status = response.status

        expect(existing_topic_status).to eq(404)
        expect(non_existing_topic_status).to eq(404)
      end
    end

    context "when logged in as a category group moderator" do
      fab!(:mod_group, :group)
      fab!(:cat_mod_user, :user)
      fab!(:private_category) { Fabricate(:private_category, group: Fabricate(:group)) }
      fab!(:private_topic) { Fabricate(:topic, category: private_category) }
      fab!(:private_claimed) { Fabricate(:reviewable_claimed_topic, topic: private_topic) }

      before do
        SiteSetting.enable_category_group_moderation = true
        SiteSetting.reviewable_claiming = "optional"
        Fabricate(:category_moderation_group, category: private_category, group: mod_group)
        mod_group.add(cat_mod_user)
        sign_in(cat_mod_user)
      end

      it "prevents unclaiming a topic the user cannot see" do
        delete "/reviewable_claimed_topics/#{private_topic.id}.json"

        expect(response.status).to eq(404)
        expect(ReviewableClaimedTopic.where(topic_id: private_topic.id).exists?).to eq(true)
      end

      it "prevents unclaiming a deleted topic the user cannot see" do
        first_post = private_topic.first_post || Fabricate(:post, topic: private_topic)
        PostDestroyer.new(Discourse.system_user, first_post, context: "Automated testing").destroy

        delete "/reviewable_claimed_topics/#{private_topic.id}.json"

        expect(response.status).to eq(404)
        expect(ReviewableClaimedTopic.where(topic_id: private_topic.id).exists?).to eq(true)
      end

      it "allows unclaiming a topic the user can see" do
        private_category.set_permissions(mod_group => :full)
        private_category.save!

        delete "/reviewable_claimed_topics/#{private_topic.id}.json"

        expect(response.status).to eq(200)
        expect(ReviewableClaimedTopic.where(topic_id: private_topic.id).exists?).to eq(false)
      end
    end

    context "when logged in as a moderator" do
      before do
        SiteSetting.reviewable_claiming = "optional"
        sign_in(moderator)
      end

      it "releases the claim, logs it, and notifies staff" do
        messages =
          MessageBus.track_publish("/reviewable_claimed") do
            delete "/reviewable_claimed_topics/#{claimed.topic_id}.json"
            expect(response.status).to eq(200)
          end

        expect(ReviewableClaimedTopic.where(topic_id: claimed.topic_id).exists?).to eq(false)
        expect(reviewable.history.unclaimed.size).to eq(1)
        expect(messages.size).to eq(1)

        message = messages[0]

        expect(message.data[:topic_id]).to eq(topic.id)
        expect(message.data[:user][:id]).to eq(moderator.id)
        expect(message.data[:claimed]).to be false
        expect(message.group_ids).to contain_exactly(Group::AUTO_GROUPS[:staff])
      end

      it "works with deleted topics" do
        first_post = topic.first_post || Fabricate(:post, topic: topic)
        PostDestroyer.new(Discourse.system_user, first_post, context: "Automated testing").destroy

        delete "/reviewable_claimed_topics/#{claimed.topic_id}.json"

        expect(response.status).to eq(200)
        expect(
          ReviewableClaimedTopic.where(user_id: moderator.id, topic_id: topic.id).exists?,
        ).to eq(false)
      end

      it "raises an error if topic is missing" do
        delete "/reviewable_claimed_topics/111111111.json"

        expect(response.status).to eq(404)
      end

      it "returns 404 when claiming is disabled" do
        SiteSetting.reviewable_claiming = "disabled"

        delete "/reviewable_claimed_topics/#{claimed.topic_id}.json"

        expect(response.status).to eq(404)
      end

      it "allows unclaiming when automatic param is present, without logging history" do
        SiteSetting.reviewable_claiming = "disabled"

        delete "/reviewable_claimed_topics/#{automatic_claimed.topic_id}.json?automatic=true"
        expect(response.status).to eq(200)
        expect(
          ReviewableClaimedTopic.where(user_id: moderator.id, topic_id: automatic_topic.id).exists?,
        ).to eq(false)
        expect(automatic_reviewable.history.unclaimed).to be_empty
      end

      it "does not log history when the claim being removed was automatic" do
        claimed.update!(automatic: true)

        messages =
          MessageBus.track_publish("/reviewable_claimed") do
            delete "/reviewable_claimed_topics/#{claimed.topic_id}.json"
            expect(response.status).to eq(200)
          end

        expect(ReviewableClaimedTopic.where(topic_id: topic.id).exists?).to eq(false)
        expect(reviewable.history.unclaimed).to be_empty
        expect(messages.size).to eq(1)
        expect(messages.first.data[:automatic]).to eq(true)
      end

      it "queues a sidekiq job to refresh reviewable counts for users who can see the reviewable" do
        SiteSetting.enable_category_group_moderation = true

        group = Fabricate(:group)
        Fabricate(:category_moderation_group, category: topic.category, group:)

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

      it "does not log history or publish when the topic was not claimed" do
        claimed.destroy!

        messages =
          MessageBus.track_publish("/reviewable_claimed") do
            delete "/reviewable_claimed_topics/#{topic.id}.json"
            expect(response.status).to eq(200)
          end

        expect(reviewable.history.unclaimed).to be_empty
        expect(messages).to be_empty
      end
    end
  end
end
