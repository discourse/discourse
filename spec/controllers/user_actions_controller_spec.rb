require 'rails_helper'
require_dependency 'post_enqueuer'

describe UserActionsController do
  context 'index' do

    it 'fails if username is not specified' do
      expect do
        get :index, format: :json
      end.to raise_error(ActionController::ParameterMissing)
    end

    it 'renders list correctly' do
      UserActionCreator.enable
      post = Fabricate(:post)

      get :index, params: { username: post.user.username }, format: :json

      expect(response.status).to eq(200)
      parsed = JSON.parse(response.body)
      actions = parsed["user_actions"]
      expect(actions.length).to eq(1)
      action = actions[0]
      expect(action["acting_name"]).to eq(post.user.name)
      expect(action["email"]).to eq(nil)
      expect(action["post_number"]).to eq(1)
    end

    it 'renders help text if provided for self' do
      logged_in = log_in

      get :index, params: {
        filter: UserAction::LIKE,
        username: logged_in.username,
        no_results_help_key: "user_activity.no_bookmarks"
      }, format: :json

      expect(response.status).to eq(200)
      parsed = JSON.parse(response.body)

      expect(parsed["no_results_help"]).to eq(I18n.t("user_activity.no_bookmarks.self"))

    end

    it 'renders help text for others' do
      user = Fabricate(:user)

      get :index, params: {
        filter: UserAction::LIKE,
        username: user.username,
        no_results_help_key: "user_activity.no_bookmarks"
      }, format: :json

      expect(response.status).to eq(200)
      parsed = JSON.parse(response.body)

      expect(parsed["no_results_help"]).to eq(I18n.t("user_activity.no_bookmarks.others"))
    end

    context "queued posts" do
      context "without access" do
        let(:user) { Fabricate(:user) }
        it "raises an exception" do
          get :index, params: {
            username: user.username, filter: UserAction::PENDING
          }, format: :json
          expect(response).to_not be_success

        end
      end

      context "with access" do
        let(:user) { log_in }

        it 'finds queued posts' do
          queued_post = PostEnqueuer.new(user, 'default').enqueue(raw: 'this is the raw enqueued content')

          get :index, params: {
            username: user.username, filter: UserAction::PENDING
          }, format: :json

          expect(response.status).to eq(200)
          parsed = JSON.parse(response.body)
          actions = parsed["user_actions"]
          expect(actions.length).to eq(1)

          action = actions.first
          expect(action['username']).to eq(user.username)
          expect(action['excerpt']).to be_present
        end
      end
    end
  end
end
