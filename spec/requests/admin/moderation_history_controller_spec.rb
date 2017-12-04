require 'rails_helper'

RSpec.describe Admin::BackupsController do
  let(:admin) { Fabricate(:admin) }

  before do
    sign_in(admin)
  end

  describe "parameters" do
    it "returns 404 without a valid filter" do
      get "/admin/moderation_history.json"
      expect(response).not_to be_success
    end

    it "returns 404 without a valid id" do
      get "/admin/moderation_history.json?filter=topic"
      expect(response).not_to be_success
    end
  end

  describe "for a post" do
    it "returns an empty array when the post doesn't exist" do
      get "/admin/moderation_history.json?filter=post&post_id=99999999"
      expect(response).to be_success
      expect(::JSON.parse(response.body)['moderation_history']).to be_blank
    end

    it "returns a history when the post exists" do
      p = Fabricate(:post)
      p = Fabricate(:post, topic_id: p.topic_id)
      PostDestroyer.new(Discourse.system_user, p).destroy
      get "/admin/moderation_history.json?filter=post&post_id=#{p.id}"
      expect(response).to be_success
      expect(::JSON.parse(response.body)['moderation_history']).to be_present
    end

  end

  describe "for a topic" do
    it "returns empty history when the topic doesn't exist" do
      get "/admin/moderation_history.json?filter=topic&topic_id=1234"
      expect(response).to be_success
      expect(::JSON.parse(response.body)['moderation_history']).to be_blank
    end

    it "returns a history when the topic exists" do
      p = Fabricate(:post)
      PostDestroyer.new(Discourse.system_user, p).destroy
      get "/admin/moderation_history.json?filter=topic&topic_id=#{p.topic_id}"
      expect(response).to be_success
      expect(::JSON.parse(response.body)['moderation_history']).to be_present
    end
  end
end
