require 'rails_helper'

describe ClicksController do

  let(:url) { "https://discourse.org/" }
  let(:headers) { { REMOTE_ADDR: "192.168.0.1" } }
  let(:post) { create_post(raw: "this is a post with a link #{url}") }

  context '#track' do
    it "creates a TopicLinkClick" do
      sign_in(Fabricate(:user))

      expect {
        get "/clicks/track", params: { url: url, post_id: post.id, topic_id: post.topic_id }, headers: headers
      }.to change { TopicLinkClick.count }.by(1)
    end
  end
end
