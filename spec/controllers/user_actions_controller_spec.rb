require 'spec_helper'

describe UserActionsController do
  context 'index' do

    it 'fails if username is not specified' do
      expect { xhr :get, :index }.to raise_error
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
  end
end
