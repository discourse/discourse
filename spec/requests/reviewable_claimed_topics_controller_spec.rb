# frozen_string_literal: true

require 'rails_helper'

describe ReviewableClaimedTopicsController do
  fab!(:moderator) { Fabricate(:moderator) }

  fab!(:topic) { Fabricate(:topic) }
  fab!(:reviewable) { Fabricate(:reviewable_flagged_post, topic: topic) }

  describe '#create' do
    let(:params) { { reviewable_claimed_topic: { topic_id: topic.id } } }

    it "requires user to be logged in" do
      post "/reviewable_claimed_topics.json", params: params

      expect(response.status).to eq(403)
    end

    context "when logged in" do
      before do
        sign_in(moderator)
      end

      it "works" do
        SiteSetting.reviewable_claiming = 'optional'

        messages = MessageBus.track_publish { post "/reviewable_claimed_topics.json", params: params }

        expect(response.status).to eq(200)
        expect(ReviewableClaimedTopic.where(user_id: moderator.id, topic_id: topic.id).exists?).to eq(true)
        expect(topic.reviewables.first.history.where(reviewable_history_type: ReviewableHistory.types[:claimed]).size).to eq(1)
        expect(messages.size).to eq(1)
        expect(messages[0].channel).to eq("/reviewable_claimed")
        expect(messages[0].data[:topic_id]).to eq(topic.id)
        expect(messages[0].data[:user][:id]).to eq(moderator.id)
      end

      it "works with deleted topics" do
        SiteSetting.reviewable_claiming = 'optional'
        first_post = topic.first_post || Fabricate(:post, topic: topic)
        PostDestroyer.new(Discourse.system_user, first_post).destroy

        post "/reviewable_claimed_topics.json", params: params

        expect(response.status).to eq(200)
        expect(ReviewableClaimedTopic.where(user_id: moderator.id, topic_id: topic.id).exists?).to eq(true)
      end

      it "raises an error if user cannot claim the topic" do
        post "/reviewable_claimed_topics.json", params: params

        expect(response.status).to eq(403)
      end

      it "raises an error if topic is already claimed" do
        SiteSetting.reviewable_claiming = 'optional'

        post "/reviewable_claimed_topics.json", params: params
        expect(ReviewableClaimedTopic.where(user_id: moderator.id, topic_id: topic.id).exists?).to eq(true)

        post "/reviewable_claimed_topics.json", params: params
        expect(response.status).to eq(409)
      end
    end
  end

  describe '#destroy' do
    fab!(:claimed) { Fabricate(:reviewable_claimed_topic, topic: topic) }

    before do
      sign_in(moderator)
    end

    it "works" do
      SiteSetting.reviewable_claiming = 'optional'

      messages = MessageBus.track_publish { delete "/reviewable_claimed_topics/#{claimed.topic_id}.json" }

      expect(response.status).to eq(200)
      expect(ReviewableClaimedTopic.where(topic_id: claimed.topic_id).exists?).to eq(false)
      expect(topic.reviewables.first.history.where(reviewable_history_type: ReviewableHistory.types[:unclaimed]).size).to eq(1)
      expect(messages.size).to eq(1)
      expect(messages[0].channel).to eq("/reviewable_claimed")
      expect(messages[0].data[:topic_id]).to eq(topic.id)
      expect(messages[0].data[:user]).to eq(nil)
    end

    it "works with deleted topics" do
      SiteSetting.reviewable_claiming = 'optional'
      first_post = topic.first_post || Fabricate(:post, topic: topic)
      PostDestroyer.new(Discourse.system_user, first_post).destroy

      delete "/reviewable_claimed_topics/#{claimed.topic_id}.json"

      expect(response.status).to eq(200)
      expect(ReviewableClaimedTopic.where(user_id: moderator.id, topic_id: topic.id).exists?).to eq(false)
    end

    it "raises an error if topic is missing" do
      delete "/reviewable_claimed_topics/111111111.json"

      expect(response.status).to eq(404)
    end

    it "raises an error if user cannot claim the topic" do
      delete "/reviewable_claimed_topics/#{claimed.topic_id}.json"

      expect(response.status).to eq(403)
    end
  end
end
