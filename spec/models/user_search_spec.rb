require 'spec_helper'

describe UserSearch do

  let(:topic)  { Fabricate :topic }
  let(:topic2) { Fabricate :topic }
  let(:topic3) { Fabricate :topic }
  let(:user1)  { Fabricate :user, username: "mrblonde", name: "Michael Madsen" }
  let(:user2)  { Fabricate :user, username: "mrblue",   name: "Eddie Bunker" }
  let(:user3)  { Fabricate :user, username: "mrorange", name: "Tim Roth" }
  let(:user4)  { Fabricate :user, username: "mrpink",   name: "Steve Buscemi" }
  let(:user5)  { Fabricate :user, username: "mrbrown",  name: "Quentin Tarantino" }
  let(:user6)  { Fabricate :user, username: "mrwhite",  name: "Harvey Keitel" }

  before do
    Fabricate :post, user: user1, topic: topic
    Fabricate :post, user: user2, topic: topic2
    Fabricate :post, user: user3, topic: topic
    Fabricate :post, user: user4, topic: topic
    Fabricate :post, user: user5, topic: topic3
    Fabricate :post, user: user6, topic: topic
  end

  # this is a seriously expensive integration test, re-creating this entire test db is too expensive
  # reuse
  it "operates correctly" do
    # normal search
    results = UserSearch.search user1.name.split(" ").first
    results.size.should == 1
    results.first.should == user1

    # lower case
    results = UserSearch.search user1.name.split(" ").first.downcase
    results.size.should == 1
    results.first.should == user1

    #  username
    results = UserSearch.search user4.username
    results.size.should == 1
    results.first.should == user4

    # case insensitive
    results = UserSearch.search user4.username.upcase
    results.size.should == 1
    results.first.should == user4

    # substrings
    results = UserSearch.search "mr"
    results.size.should == 6

    results = UserSearch.search "mrb"
    results.size.should == 3


    results = UserSearch.search "MR"
    results.size.should == 6

    results = UserSearch.search "MRB"
    results.size.should == 3

    # topic priority
    results = UserSearch.search "mrb", topic.id
    results.first.should == user1


    results = UserSearch.search "mrb", topic2.id
    results.first.should == user2

    results = UserSearch.search "mrb", topic3.id
    results.first.should == user5
  end

end
