# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseBoosts::BoostsController do
  fab!(:current_user, :user)
  fab!(:post_author, :user)
  fab!(:topic)
  fab!(:target_post, :post) { Fabricate(:post, topic: topic, user: post_author) }

  before do
    SiteSetting.discourse_boosts_enabled = true
    sign_in(current_user)
  end

  describe "#create" do
    it "works" do
      post "/discourse-boosts/posts/#{target_post.id}/boosts.json", params: { raw: "🎉" }

      expect(response.status).to eq(200)
      expect(response.parsed_body["raw"]).to eq("🎉")
      expect(response.parsed_body["user"]["id"]).to eq(current_user.id)
    end

    context "when params are invalid" do
      it "returns a 400" do
        post "/discourse-boosts/posts/#{target_post.id}/boosts.json", params: { raw: "" }
        expect(response.status).to eq(400)
      end
    end

    context "when post doesn't exist" do
      it "returns a 404" do
        post "/discourse-boosts/posts/-1/boosts.json", params: { raw: "🎉" }
        expect(response.status).to eq(404)
      end
    end

    context "when boosting own post" do
      fab!(:current_user) { post_author }

      it "returns a 403" do
        post "/discourse-boosts/posts/#{target_post.id}/boosts.json", params: { raw: "🎉" }
        expect(response.status).to eq(403)
      end
    end

    context "when boost limit is reached" do
      before do
        SiteSetting.discourse_boosts_max_per_user_per_post = 1
        Fabricate(:boost, post: target_post, user: current_user)
      end

      it "returns a 422" do
        post "/discourse-boosts/posts/#{target_post.id}/boosts.json", params: { raw: "🎉" }
        expect(response.status).to eq(422)
      end
    end
  end

  describe "#destroy" do
    fab!(:boost) { Fabricate(:boost, post: target_post, user: current_user) }

    it "works" do
      delete "/discourse-boosts/boosts/#{boost.id}.json"

      expect(response.status).to eq(204)
      expect(DiscourseBoosts::Boost.exists?(boost.id)).to eq(false)
    end

    context "when boost doesn't exist" do
      it "returns a 404" do
        delete "/discourse-boosts/boosts/-1.json"
        expect(response.status).to eq(404)
      end
    end

    context "when user is not the author" do
      fab!(:boost) { Fabricate(:boost, post: target_post, user: post_author) }

      it "returns a 403" do
        delete "/discourse-boosts/boosts/#{boost.id}.json"
        expect(response.status).to eq(403)
      end
    end

    context "when user is an admin" do
      fab!(:current_user, :admin)
      fab!(:boost) { Fabricate(:boost, post: target_post, user: post_author) }

      it "works" do
        delete "/discourse-boosts/boosts/#{boost.id}.json"
        expect(response.status).to eq(204)
      end
    end
  end

  describe "#index" do
    fab!(:boost) { Fabricate(:boost, post: target_post, user: current_user) }

    before { SiteSetting.hide_new_user_profiles = false }

    it "works" do
      get "/discourse-boosts/users/#{post_author.username}/boosts.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["boosts"].length).to eq(1)
    end

    context "when user doesn't exist" do
      it "returns a 404" do
        get "/discourse-boosts/users/nonexistent_user/boosts.json"
        expect(response.status).to eq(404)
      end
    end
  end
end
