# frozen_string_literal: true

require 'rails_helper'

describe ClicksController do

  let(:url) { "https://discourse.org/" }
  let(:headers) { { REMOTE_ADDR: "192.168.0.1" } }
  let(:post_with_url) { create_post(raw: "this is a post with a link #{url}") }

  context '#track' do
    it "creates a TopicLinkClick" do
      sign_in(Fabricate(:user))

      expect {
        post "/clicks/track", params: { url: url, post_id: post_with_url.id, topic_id: post_with_url.topic_id }, headers: headers
      }.to change { TopicLinkClick.count }.by(1)
    end
  end
end
