# frozen_string_literal: true

RSpec.describe AppreciationsController do
  fab!(:user)
  fab!(:other_user, :user)
  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic: topic, user: other_user) }

  before { sign_in(user) }

  describe "#given" do
    before { PostActionCreator.like(user, post) }

    it "returns appreciations given by the user" do
      get "/u/#{user.username}/appreciations/given.json"

      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["appreciations"].length).to eq(1)

      appreciation = json["appreciations"].first
      expect(appreciation["type"]).to eq("like")
      expect(appreciation["post"]["id"]).to eq(post.id)
      expect(appreciation["acting_user"]["id"]).to eq(user.id)
    end

    it "supports pagination via before param" do
      other_post = Fabricate(:post, topic: topic, user: other_user)
      PostActionCreator.like(user, other_post)

      get "/u/#{user.username}/appreciations/given.json"
      first_appreciation = response.parsed_body["appreciations"].first

      get "/u/#{user.username}/appreciations/given.json",
          params: {
            before: first_appreciation["created_at"],
          }

      expect(response.status).to eq(200)
      expect(response.parsed_body["appreciations"].length).to eq(1)
    end

    it "supports filtering by type" do
      get "/u/#{user.username}/appreciations/given.json", params: { types: "like" }

      expect(response.status).to eq(200)
      expect(response.parsed_body["appreciations"].length).to eq(1)
    end

    it "returns 404 for nonexistent user" do
      get "/u/nonexistent_user/appreciations/given.json"
      expect(response.status).to eq(404)
    end

    context "when profile is hidden" do
      fab!(:hidden_user, :user)

      before do
        SiteSetting.allow_users_to_hide_profile = true
        hidden_user.user_option.update!(hide_profile_and_presence: true)
        PostActionCreator.like(hidden_user, post)
      end

      it "returns 404 when viewing another user's hidden profile" do
        get "/u/#{hidden_user.username}/appreciations/given.json"
        expect(response.status).to eq(404)
      end
    end
  end

  describe "#received" do
    before { PostActionCreator.like(other_user, Fabricate(:post, topic: topic, user: user)) }

    it "returns appreciations received by the user" do
      get "/u/#{user.username}/appreciations/received.json"

      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["appreciations"].length).to eq(1)

      appreciation = json["appreciations"].first
      expect(appreciation["type"]).to eq("like")
      expect(appreciation["acting_user"]["id"]).to eq(other_user.id)
    end

    it "returns 403 when viewing another user's received appreciations" do
      get "/u/#{other_user.username}/appreciations/received.json"
      expect(response.status).to eq(403)
    end
  end

  context "when not logged in" do
    before { sign_out }

    it "can view given appreciations on public profiles" do
      PostActionCreator.like(user, post)
      get "/u/#{user.username}/appreciations/given.json"
      expect(response.status).to eq(200)
    end
  end
end
