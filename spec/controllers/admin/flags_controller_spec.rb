require 'spec_helper'

describe Admin::FlagsController do

  it "is a subclass of AdminController" do
    (Admin::FlagsController < Admin::AdminController).should == true
  end

  context 'while logged in as an admin' do
    before do
      @user = log_in(:admin)
    end

    context 'index' do
      it 'returns empty json when nothing is flagged' do
        xhr :get, :index

        data = ::JSON.parse(response.body)
        data["users"].should == []
        data["posts"].should == []
      end

      it 'returns a valid json payload when some thing is flagged' do
        p = Fabricate(:post)
        u = Fabricate(:user)

        PostAction.act(u, p, PostActionType.types[:spam])
        xhr :get, :index

        data = ::JSON.parse(response.body)
        data["users"].length == 2
        data["posts"].length == 1
      end
    end
  end
end

