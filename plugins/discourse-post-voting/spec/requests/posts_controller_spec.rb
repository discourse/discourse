# frozen_string_literal: true

describe PostsController do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }

  describe "#create" do
    before do
      sign_in(user)
      SiteSetting.post_voting_enabled = true
    end

    it "creates a topic with the right subtype when create_as_post_voting param is provided" do
      post "/posts.json",
           params: {
             raw: "this is some raw",
             title: "this is some title",
             create_as_post_voting: true,
           }

      expect(response.status).to eq(200)

      topic = Topic.last

      expect(topic.is_post_voting?).to eq(true)
    end

    it "ignores create_as_post_voting param when trying to create private message" do
      Group.refresh_automatic_groups!
      post "/posts.json",
           params: {
             raw: "this is some raw",
             title: "this is some title",
             create_as_post_voting: true,
             archetype: Archetype.private_message,
             target_recipients: user.username,
           }

      expect(response.status).to eq(200)

      topic = Topic.last

      expect(topic.is_post_voting?).to eq(false)
    end

    it "returns all post-voting fields" do
      topic = Fabricate(:topic, subtype: Topic::POST_VOTING_SUBTYPE)

      post "/posts.json", params: { raw: "this is some raw", topic_id: topic.id }

      expect(response.parsed_body["post_voting_vote_count"]).to eq(0)
      expect(response.parsed_body["post_voting_has_votes"]).to eq(false)
      expect(response.parsed_body["comments"]).to eq([])
      expect(response.parsed_body["comments_count"]).to eq(0)
    end
  end
end
