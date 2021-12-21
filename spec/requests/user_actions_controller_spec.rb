# frozen_string_literal: true

require 'rails_helper'

describe UserActionsController do
  context 'index' do

    it 'fails if username is not specified' do
      get "/user_actions.json"
      expect(response.status).to eq(400)
    end

    it 'renders list correctly' do
      UserActionManager.enable
      post = create_post

      get "/user_actions.json", params: { username: post.user.username }

      expect(response.status).to eq(200)
      parsed = response.parsed_body
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

      response_body = response.parsed_body

      expect(response_body["user_actions"].count).to eq(1)

      expect(response_body["user_actions"].first["acting_username"])
        .to eq(user.username)
    end

    context 'hidden profiles' do
      fab!(:post) { Fabricate(:post) }

      before do
        UserActionManager.enable
        post.user.user_option.update_column(:hide_profile_and_presence, true)
      end

      it "returns a 404" do
        get "/user_actions.json", params: { username: post.user.username }
        expect(response.code).to eq("404")
      end

      it "succeeds when `allow_users_to_hide_profile` is false" do
        SiteSetting.allow_users_to_hide_profile = false
        get "/user_actions.json", params: { username: post.user.username }
        expect(response.code).to eq("200")
      end
    end

    context "other users' activity" do
      fab!(:another_user) { Fabricate(:user) }

      UserAction.private_types.each do |action_type|
        action_name = UserAction.types.key(action_type)
        it "anonymous users cannot list other users' actions of type: #{action_name}" do
          list_and_check(action_type, 404)
        end
      end

      UserAction.private_types.each do |action_type|
        fab!(:user) { Fabricate(:user) }
        action_name = UserAction.types.key(action_type)

        it "logged in users cannot list other users' actions of type: #{action_name}" do
          sign_in(user)
          list_and_check(action_type, 404)
        end
      end

      UserAction.private_types.each do |action_type|
        fab!(:moderator) { Fabricate(:moderator) }
        action_name = UserAction.types.key(action_type)

        it "moderators cannot list other users' actions of type: #{action_name}" do
          sign_in(moderator)
          list_and_check(action_type, 404)
        end
      end

      UserAction.private_types.each do |action_type|
        fab!(:admin) { Fabricate(:admin) }
        action_name = UserAction.types.key(action_type)

        it "admins can list other users' actions of type: #{action_name}" do
          sign_in(admin)
          list_and_check(action_type, 200)
        end
      end

      def list_and_check(action_type, expected_response)
        get "/user_actions.json", params: {
          filter: action_type,
          username: another_user.username
        }

        expect(response.status).to eq(expected_response)
      end
    end
  end
end
