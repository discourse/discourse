require 'spec_helper'

describe UserTrackingState do

  let(:user) do
    Fabricate(:user)
  end

  let(:post) do
    Fabricate(:post)
  end

  let(:state) do
    UserTrackingState.new(user)
  end

  it "correctly gets the list of new topics" do
    state.new_list.should == []
    state.unread_list.should == []

    new_post = post

    new_list = state.new_list

    new_list.length.should == 1
    new_list[0][0].should == post.topic.id
    new_list[0][1].should be_within(1.second).of(post.topic.created_at)

    state.unread_list.should == []

    # read it

  end
end
