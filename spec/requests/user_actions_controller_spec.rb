# frozen_string_literal: true

require 'rails_helper'

describe UserActionsController do
  context 'index' do

    it 'fails if username is not specified' do
      get "/user_actions.json"
      expect(response.status).to eq(400)
    end

    it "returns a 404 for a user with a hidden profile" do
      UserActionManager.enable
      post = Fabricate(:post)
      post.user.user_option.update_column(:hide_profile_and_presence, true)

      get "/user_actions.json", params: { username: post.user.username }
      expect(response.code).to eq("404")
    end

    it 'renders list correctly' do
      UserActionManager.enable
      post = create_post

      get "/user_actions.json", params: { username: post.user.username }

      expect(response.status).to eq(200)
      parsed = JSON.parse(response.body)
      actions = parsed["user_actions"]
      expect(actions.length).to eq(1)
      action = actions[0]
      expect(action["acting_name"]).to eq(post.user.name)
      expect(action["email"]).to eq(nil)
      expect(action["post_number"]).to eq(1)
    end

    it 'can be filtered by acting_username' do
      UserActionManager.enable
      PostActionNotifier.enable

      post = Fabricate(:post)
      user = Fabricate(:user)
      PostActionCreator.like(user, post)

      get "/user_actions.json", params: {
        username: post.user.username,
        acting_username: user.username
      }

      expect(response.status).to eq(200)

      response_body = JSON.parse(response.body)

      expect(response_body["user_actions"].count).to eq(1)

      expect(response_body["user_actions"].first["acting_username"])
        .to eq(user.username)
    end

    it 'renders help text if provided for self' do
      logged_in = sign_in(Fabricate(:user))

      get "/user_actions.json", params: {
        filter: UserAction::LIKE,
        username: logged_in.username,
        no_results_help_key: "user_activity.no_bookmarks"
      }

      expect(response.status).to eq(200)
      parsed = JSON.parse(response.body)

      expect(parsed["no_results_help"]).to eq(I18n.t("user_activity.no_bookmarks.self"))
    end

    it 'renders help text for others' do
      user = Fabricate(:user)

      get "/user_actions.json", params: {
        filter: UserAction::LIKE,
        username: user.username,
        no_results_help_key: "user_activity.no_bookmarks"
      }

      expect(response.status).to eq(200)
      parsed = JSON.parse(response.body)

      expect(parsed["no_results_help"]).to eq(I18n.t("user_activity.no_bookmarks.others"))
    end

  end
end
