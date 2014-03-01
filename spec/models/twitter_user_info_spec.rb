require 'spec_helper'

describe TwitterUserInfo do
  it "does not overflow" do
    id =  22019458041
    info = TwitterUserInfo.create!(user_id: -1, screen_name: 'sam', twitter_user_id: id)
    info.reload
    info.twitter_user_id.should == id
  end
end
