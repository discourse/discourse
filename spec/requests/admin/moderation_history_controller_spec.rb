require 'rails_helper'

RSpec.describe Admin::ModerationHistoryController do
  let(:admin) { Fabricate(:admin) }

  before do
    sign_in(admin)
  end

  describe "parameters" do
    it "returns 404 without a valid filter" do
      get "/admin/moderation_history.json"
      expect(response).not_to be_successful
    end

    it "returns 404 without a valid id" do
      get "/admin/moderation_history.json?filter=topic"
      expect(response).not_to be_successful
    end
  end

  describe "for a post" do
    it "returns an empty array when the post doesn't exist" do
      get "/admin/moderation_history.json?filter=post&post_id=99999999"
      expect(response.status).to eq(200)
      expect(::JSON.parse(response.body)['moderation_history']).to be_blank
    end

    it "returns a history when the post exists" do
      p = Fabricate(:post)
      p = Fabricate(:post, topic: p.topic)
      PostDestroyer.new(Discourse.system_user, p).destroy
      get "/admin/moderation_history.json?filter=post&post_id=#{p.id}"
      expect(response.status).to eq(200)
      expect(::JSON.parse(response.body)['moderation_history']).to be_present
    end

    it 'includes post approval record' do
      reviewable = Fabricate(:reviewable_queued_post)
      result = reviewable.perform(Discourse.system_user, :approve)

      get "/admin/moderation_history.json?filter=post&post_id=#{result.created_post.id}"

      expect(response.status).to eq(200)

      moderation_history = JSON.parse(response.body)['moderation_history'].first
      expect(moderation_history['action_name']).to eq('post_approved')
    end
  end

  describe "for a topic" do
    it "returns empty history when the topic doesn't exist" do
      get "/admin/moderation_history.json?filter=topic&topic_id=1234"
      expect(response.status).to eq(200)
      expect(::JSON.parse(response.body)['moderation_history']).to be_blank
    end

    it "returns a history when the topic exists" do
      p = Fabricate(:post)
      PostDestroyer.new(Discourse.system_user, p).destroy
      get "/admin/moderation_history.json?filter=topic&topic_id=#{p.topic_id}"
      expect(response.status).to eq(200)
      expect(::JSON.parse(response.body)['moderation_history']).to be_present
    end
  end
end
