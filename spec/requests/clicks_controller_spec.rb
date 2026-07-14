# frozen_string_literal: true

RSpec.describe ClicksController do
  fab!(:user, :trust_level_1)
  fab!(:recipient, :trust_level_1)
  fab!(:unauthorized_user, :user)

  let(:url) { "https://discourse.org/" }
  let(:headers) { { REMOTE_ADDR: "192.168.0.1" } }
  let(:post_with_url) { create_post(raw: "this is a post with a link #{url}") }

  describe "#track" do
    it "creates a TopicLinkClick" do
      sign_in(user)

      expect {
        post "/clicks/track",
             params: {
               url: url,
               post_id: post_with_url.id,
               topic_id: post_with_url.topic_id,
             },
             headers: headers
      }.to change { TopicLinkClick.count }.by(1)

      expect(response.status).to eq(200)
      expect(response.parsed_body["success"]).to eq("OK")
    end

    it "creates a TopicLinkClick for a private message post the recipient can see" do
      private_url = "https://example.com/private-recipient-click-test"
      private_message_post =
        create_post(
          user: user,
          archetype: Archetype.private_message,
          target_usernames: [recipient.username],
          raw: "this private message has a link #{private_url}",
        )
      expect(private_message_post.topic_links.find_by(url: private_url)).to be_present

      sign_in(recipient)

      expect {
        post "/clicks/track",
             params: {
               url: private_url,
               post_id: private_message_post.id,
               topic_id: private_message_post.topic_id,
             },
             headers: headers
      }.to change { TopicLinkClick.count }.by(1)

      expect(response.status).to eq(200)
      expect(response.parsed_body["success"]).to eq("OK")
    end

    it "does not create a TopicLinkClick for a private message post the user cannot see" do
      private_url = "https://example.com/private-click-test"
      private_message_post =
        create_post(
          user: user,
          archetype: Archetype.private_message,
          target_usernames: [recipient.username],
          raw: "this private message has a link #{private_url}",
        )
      expect(private_message_post.topic_links.find_by(url: private_url)).to be_present

      sign_in(unauthorized_user)

      expect {
        post "/clicks/track",
             params: {
               url: private_url,
               post_id: private_message_post.id,
               topic_id: private_message_post.topic_id,
             },
             headers: headers
      }.not_to change { TopicLinkClick.count }

      expect(response.status).to eq(200)
      expect(response.parsed_body["success"]).to eq("OK")
    end
  end
end
