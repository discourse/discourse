# frozen_string_literal: true

require "rails_helper"
require_relative "../support/api_schema_matcher"

RSpec.describe DiscourseBoosts::BoostsController do
  fab!(:current_user, :user)
  fab!(:post_author, :user)
  fab!(:category)
  fab!(:topic) { Fabricate(:topic, category: category) }
  fab!(:target_post, :post) { Fabricate(:post, topic: topic, user: post_author) }

  before { SiteSetting.discourse_boosts_enabled = true }

  describe "#create" do
    context "when plugin is disabled" do
      before do
        SiteSetting.discourse_boosts_enabled = false
        sign_in(current_user)
      end

      it "returns a 404" do
        post "/discourse-boosts/posts/#{target_post.id}/boosts.json", params: { raw: "🎉" }
        expect(response.status).to eq(404)
      end
    end

    context "when not logged in" do
      it "returns a 403" do
        post "/discourse-boosts/posts/#{target_post.id}/boosts.json", params: { raw: "🎉" }
        expect(response.status).to eq(403)
      end
    end

    context "when logged in" do
      before { sign_in(current_user) }

      it "works" do
        post "/discourse-boosts/posts/#{target_post.id}/boosts.json", params: { raw: "🎉" }

        expect(response.status).to eq(200)
        expect(response.parsed_body["cooked"]).to include("tada")
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

      context "when user has already boosted the post" do
        before { Fabricate(:boost, post: target_post, user: current_user) }

        it "returns a 422" do
          post "/discourse-boosts/posts/#{target_post.id}/boosts.json", params: { raw: "🎉" }
          expect(response.status).to eq(422)
        end
      end

      context "when the post has reached the max boosts limit" do
        before { SiteSetting.discourse_boosts_max_per_post = 1 }

        fab!(:other_user, :user)
        fab!(:existing_boost) { Fabricate(:boost, post: target_post, user: other_user) }

        it "returns a 422" do
          post "/discourse-boosts/posts/#{target_post.id}/boosts.json", params: { raw: "🎉" }

          expect(response.status).to eq(422)
          expect(response.parsed_body["errors"].first).to eq(
            I18n.t("discourse_boosts.post_boost_limit_reached"),
          )
        end
      end

      context "when rate limit is exceeded" do
        fab!(:other_posts) { Array.new(6) { Fabricate(:post, topic: topic, user: post_author) } }

        before { RateLimiter.enable }

        it "returns a 429" do
          other_posts.each do |other_post|
            post "/discourse-boosts/posts/#{other_post.id}/boosts.json", params: { raw: "🎉" }
          end

          expect(response.status).to eq(429)
        end
      end

      context "when a duplicate key error occurs while creating the boost" do
        before do
          allow(DiscourseBoosts::Boost).to receive(:create).and_raise(
            ActiveRecord::RecordNotUnique.new("duplicate key value violates unique constraint"),
          )
        end

        it "returns a 422" do
          post "/discourse-boosts/posts/#{target_post.id}/boosts.json", params: { raw: "🎉" }
          expect(response.status).to eq(422)
        end
      end
    end
  end

  describe "#destroy" do
    fab!(:boost) { Fabricate(:boost, post: target_post, user: current_user) }

    context "when plugin is disabled" do
      before do
        SiteSetting.discourse_boosts_enabled = false
        sign_in(current_user)
      end

      it "returns a 404" do
        delete "/discourse-boosts/boosts/#{boost.id}.json"
        expect(response.status).to eq(404)
      end
    end

    context "when not logged in" do
      it "returns a 403" do
        delete "/discourse-boosts/boosts/#{boost.id}.json"
        expect(response.status).to eq(403)
      end
    end

    context "when logged in" do
      before { sign_in(current_user) }

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

      context "when rate limit is exceeded" do
        fab!(:other_posts) { Array.new(6) { Fabricate(:post, topic: topic, user: post_author) } }
        fab!(:boosts) { other_posts.map { |p| Fabricate(:boost, post: p, user: current_user) } }

        before { RateLimiter.enable }

        it "returns a 429" do
          boosts.each { |b| delete "/discourse-boosts/boosts/#{b.id}.json" }

          expect(response.status).to eq(429)
        end
      end
    end
  end

  describe "#flag" do
    fab!(:boost_author, :user)
    fab!(:boost) { Fabricate(:boost, post: target_post, user: boost_author) }

    context "when not logged in" do
      it "returns a 403" do
        post "/discourse-boosts/boosts/#{boost.id}/flags.json",
             params: {
               flag_type_id: ReviewableScore.types[:spam],
             }
        expect(response.status).to eq(403)
      end
    end

    context "when logged in" do
      before { sign_in(current_user) }

      it "works" do
        post "/discourse-boosts/boosts/#{boost.id}/flags.json",
             params: {
               flag_type_id: ReviewableScore.types[:spam],
             }
        expect(response.status).to eq(200)
      end

      context "when boost doesn't exist" do
        it "returns a 404" do
          post "/discourse-boosts/boosts/-1/flags.json",
               params: {
                 flag_type_id: ReviewableScore.types[:spam],
               }
          expect(response.status).to eq(404)
        end
      end

      context "when flagging own boost" do
        fab!(:boost) { Fabricate(:boost, post: target_post, user: current_user) }

        it "returns a 403" do
          post "/discourse-boosts/boosts/#{boost.id}/flags.json",
               params: {
                 flag_type_id: ReviewableScore.types[:spam],
               }
          expect(response.status).to eq(403)
        end
      end

      context "when rate limit is exceeded" do
        before { RateLimiter.enable }

        it "returns a 429" do
          5.times do
            post "/discourse-boosts/boosts/#{boost.id}/flags.json",
                 params: {
                   flag_type_id: ReviewableScore.types[:spam],
                 }
          end
          expect(response.status).to eq(429)
        end
      end
    end
  end

  describe "#boosts_given" do
    fab!(:boost) { Fabricate(:boost, post: target_post, user: current_user) }

    before { SiteSetting.hide_new_user_profiles = false }

    context "when plugin is disabled" do
      before { SiteSetting.discourse_boosts_enabled = false }

      it "returns a 404" do
        get "/discourse-boosts/users/#{current_user.username}/boosts-given.json"
        expect(response.status).to eq(404)
      end
    end

    context "when not logged in" do
      it "returns boosts given by the user" do
        get "/discourse-boosts/users/#{current_user.username}/boosts-given.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body["boosts"].length).to eq(1)
      end
    end

    context "when logged in" do
      before { sign_in(current_user) }

      it "returns boosts given by the user matching the expected schema" do
        get "/discourse-boosts/users/#{current_user.username}/boosts-given.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body).to match_response_schema("boost_list")
        expect(response.parsed_body["boosts"].length).to eq(1)
      end

      context "with before_boost_id pagination" do
        fab!(:another_post, :post) { Fabricate(:post, topic: topic, user: post_author) }
        fab!(:newer_boost) { Fabricate(:boost, post: another_post, user: current_user) }

        it "returns only boosts before the given id" do
          get "/discourse-boosts/users/#{current_user.username}/boosts-given.json",
              params: {
                before_boost_id: newer_boost.id,
              }

          expect(response.status).to eq(200)
          expect(response.parsed_body["boosts"].map { |b| b["id"] }).to eq([boost.id])
        end
      end

      context "when user doesn't exist" do
        it "returns a 404" do
          get "/discourse-boosts/users/nonexistent_user/boosts-given.json"
          expect(response.status).to eq(404)
        end
      end
    end
  end

  describe "#boosts_received" do
    fab!(:boost) { Fabricate(:boost, post: target_post, user: current_user) }

    context "when plugin is disabled" do
      before do
        SiteSetting.discourse_boosts_enabled = false
        sign_in(post_author)
      end

      it "returns a 404" do
        get "/discourse-boosts/users/#{post_author.username}/boosts-received.json"
        expect(response.status).to eq(404)
      end
    end

    context "when logged in as the target user" do
      before { sign_in(post_author) }

      it "returns boosts received on the user's posts" do
        get "/discourse-boosts/users/#{post_author.username}/boosts-received.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body["boosts"].length).to eq(1)
      end

      it "returns boosts matching the expected schema" do
        get "/discourse-boosts/users/#{post_author.username}/boosts-received.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body).to match_response_schema("boost_list")
      end

      context "with before_boost_id pagination" do
        fab!(:other_user, :user)
        fab!(:newer_boost) { Fabricate(:boost, post: target_post, user: other_user) }

        it "returns only boosts before the given id" do
          get "/discourse-boosts/users/#{post_author.username}/boosts-received.json",
              params: {
                before_boost_id: newer_boost.id,
              }

          expect(response.status).to eq(200)
          expect(response.parsed_body["boosts"].map { |b| b["id"] }).to eq([boost.id])
        end
      end
    end

    context "when logged in as another user" do
      fab!(:other_user, :user)

      before { sign_in(other_user) }

      it "returns a 403" do
        get "/discourse-boosts/users/#{post_author.username}/boosts-received.json"
        expect(response.status).to eq(403)
      end
    end

    context "when not logged in" do
      it "returns a 403" do
        get "/discourse-boosts/users/#{post_author.username}/boosts-received.json"
        expect(response.status).to eq(403)
      end
    end
  end
end
