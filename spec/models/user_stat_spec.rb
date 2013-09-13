require 'spec_helper'

describe UserStat do

  it { should belong_to :user }

  it "is created automatically when a user is created" do
    user = Fabricate(:evil_trout)
    user.user_stat.should be_present
  end

end