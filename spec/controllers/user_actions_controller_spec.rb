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

      response.status.should == 200
      parsed = JSON.parse(response.body)
      actions = parsed["user_actions"]
      actions.length.should == 1
      action = actions[0]
      action["acting_name"].should == post.user.name
      action["email"].should be_nil
      action["post_number"].should == 1
    end
  end
end
