require 'rails_helper'
require_dependency 'post_enqueuer'

describe UserActionsController do
  context 'index' do

    it 'fails if username is not specified' do
      expect { xhr :get, :index }.to raise_error(ActionController::ParameterMissing)
    end

    it 'renders list correctly' do
      ActiveRecord::Base.observers.enable :all
      post = Fabricate(:post)

      xhr :get, :index, username: post.user.username

      expect(response.status).to eq(200)
      parsed = JSON.parse(response.body)
      actions = parsed["user_actions"]
      expect(actions.length).to eq(1)
      action = actions[0]
      expect(action["acting_name"]).to eq(post.user.name)
      expect(action["email"]).to eq(nil)
      expect(action["post_number"]).to eq(1)
    end

    context "queued posts" do
      context "without access" do
        let(:user) { Fabricate(:user) }
        it "raises an exception" do
          xhr :get, :index, username: user.username, filter: UserAction::PENDING
          expect(response).to_not be_success

        end
      end

      context "with access" do
        let(:user) { log_in }

        it 'finds queued posts' do
          queued_post = PostEnqueuer.new(user, 'default').enqueue(raw: 'this is the raw enqueued content')

          xhr :get, :index, username: user.username, filter: UserAction::PENDING

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
