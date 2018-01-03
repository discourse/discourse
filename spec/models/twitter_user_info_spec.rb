require 'rails_helper'

describe TwitterUserInfo do
  it "does not overflow" do
    id = 22019458041
    info = TwitterUserInfo.create!(user_id: -1, screen_name: 'sam', twitter_user_id: id)
    info.reload
    expect(info.twitter_user_id).to eq(id)
  end
end
