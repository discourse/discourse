# frozen_string_literal: true

require 'rails_helper'

describe ReviewableClaimedTopicsController do
  fab!(:moderator) { Fabricate(:moderator) }

  describe '#create' do
    let(:topic) { Fabricate(:topic) }
    let(:params) do
      { reviewable_claimed_topic: { topic_id: topic.id } }
    end

    it "requires you to be logged in" do
      post "/reviewable_claimed_topics.json", params: params
      expect(response.code).to eq("403")
    end

    context "when logged in" do

      before do
        sign_in(moderator)
      end

      it "will raise an error if you can't claim the topic" do
        post "/reviewable_claimed_topics.json", params: params
        expect(response.code).to eq("403")
      end

      it "will return 200 if the user can claim the topic" do
        SiteSetting.reviewable_claiming = 'optional'
        post "/reviewable_claimed_topics.json", params: params
        expect(response.code).to eq("200")
        expect(ReviewableClaimedTopic.where(user_id: moderator.id, topic_id: topic.id).exists?).to eq(true)
      end
    end
  end

  describe '#destroy' do
    let(:claimed) { Fabricate(:reviewable_claimed_topic) }

    before do
      sign_in(moderator)
    end

    it "404s for a missing topic" do
      delete "/reviewable_claimed_topics/111111111.json"
      expect(response.code).to eq("404")
    end

    it "403s when you can't claim the topic" do
      delete "/reviewable_claimed_topics/#{claimed.topic_id}.json"
      expect(response.code).to eq("403")
    end

    it "works when the feature is enabled" do
      SiteSetting.reviewable_claiming = 'optional'
      delete "/reviewable_claimed_topics/#{claimed.topic_id}.json"
      expect(response.code).to eq("200")
      expect(ReviewableClaimedTopic.where(topic_id: claimed.topic_id).exists?).to eq(false)
    end
  end
end
