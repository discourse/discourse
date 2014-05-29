require 'spec_helper'

describe UserProfile do
  it "is created automatically when a user is created" do
    user = Fabricate(:evil_trout)
    user.user_profile.should be_present
  end
end
