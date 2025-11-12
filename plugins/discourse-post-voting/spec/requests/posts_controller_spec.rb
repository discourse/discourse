# frozen_string_literal: true

describe PostsController do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:category)

  describe "#create" do
    before do
      sign_in(user)
      SiteSetting.post_voting_enabled = true
      user.update!(trust_level: TrustLevel[1])
      Group.refresh_automatic_groups!
    end

    it "creates a topic with the right subtype when create_as_post_voting param is provided" do
      post "/posts.json",
           params: {
             raw: "this is some raw",
             title: "this is some title",
             create_as_post_voting: true,
             category: category.id,
           }

      expect(response.status).to eq(200)

      topic = Topic.last

      expect(topic.is_post_voting?).to eq(true)
    end

    it "ignores create_as_post_voting param when trying to create private message" do
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

    context "with post_voting_create_allowed_groups setting" do
      fab!(:group)
      fab!(:allowed_user) { Fabricate(:user, refresh_auto_groups: true) }
      fab!(:disallowed_user) { Fabricate(:user, refresh_auto_groups: true) }

      before do
        group.add(allowed_user)
        SiteSetting.post_voting_create_allowed_groups = group.id.to_s
      end

      it "allows users in allowed groups to create post voting topics" do
        sign_in(allowed_user)

        post "/posts.json",
             params: {
               raw: "this is some raw",
               title: "this is some title",
               create_as_post_voting: true,
               category: category.id,
             }

        expect(response.status).to eq(200)

        topic = Topic.last
        expect(topic.is_post_voting?).to eq(true)
      end

      it "prevents users not in allowed groups from creating post voting topics" do
        sign_in(disallowed_user)

        post "/posts.json",
             params: {
               raw: "this is some raw",
               title: "this is some title",
               create_as_post_voting: true,
               category: category.id,
             }

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to include(
          I18n.t("post_voting.errors.cannot_create_post_voting_topic"),
        )
      end

      it "allows staff to create post voting topics regardless of group membership" do
        admin = Fabricate(:admin)
        sign_in(admin)

        post "/posts.json",
             params: {
               raw: "this is some raw",
               title: "this is some title",
               create_as_post_voting: true,
               category: category.id,
             }

        expect(response.status).to eq(200)

        topic = Topic.last
        expect(topic.is_post_voting?).to eq(true)
      end
    end
  end
end
