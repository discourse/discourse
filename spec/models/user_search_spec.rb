require 'spec_helper'

describe UserSearch do

  let(:topic)     { Fabricate :topic }
  let(:topic2)    { Fabricate :topic }
  let(:topic3)    { Fabricate :topic }
  let(:user1)     { Fabricate :user, username: "mrblonde", name: "Michael Madsen" }
  let(:user2)     { Fabricate :user, username: "mrblue",   name: "Eddie Bunker" }
  let(:user3)     { Fabricate :user, username: "mrorange", name: "Tim Roth" }
  let(:user4)     { Fabricate :user, username: "mrpink",   name: "Steve Buscemi" }
  let(:user5)     { Fabricate :user, username: "mrbrown",  name: "Quentin Tarantino" }
  let(:user6)     { Fabricate :user, username: "mrwhite",  name: "Harvey Keitel" }
  let(:admin)     { Fabricate :admin, username: "theadmin" }
  let(:moderator) { Fabricate :moderator, username: "themod" }

  before do
    Fabricate :post, user: user1, topic: topic
    Fabricate :post, user: user2, topic: topic2
    Fabricate :post, user: user3, topic: topic
    Fabricate :post, user: user4, topic: topic
    Fabricate :post, user: user5, topic: topic3
    Fabricate :post, user: user6, topic: topic
    user6.update_attributes(suspended_at: 1.day.ago, suspended_till: 1.year.from_now)
  end

  def search_for(*args)
    UserSearch.new(*args).search
  end

  # this is a seriously expensive integration test, re-creating this entire test db is too expensive
  # reuse
  it "operates correctly" do
    # normal search
    results = search_for(user1.name.split(" ").first)
    results.size.should == 1
    results.first.should == user1

    # lower case
    results = search_for(user1.name.split(" ").first.downcase)
    results.size.should == 1
    results.first.should == user1

    #  username
    results = search_for(user4.username)
    results.size.should == 1
    results.first.should == user4

    # case insensitive
    results = search_for(user4.username.upcase)
    results.size.should == 1
    results.first.should == user4

    # substrings
    # only staff members see suspended users in results
    results = search_for("mr")
    results.size.should == 5
    results.should_not include(user6)
    search_for("mr", searching_user: user1).size.should == 5

    results = search_for("mr", searching_user: admin)
    results.size.should == 6
    results.should include(user6)
    search_for("mr", searching_user: moderator).size.should == 6

    results = search_for("mrb", searching_user: admin)
    results.size.should == 3


    results = search_for("MR", searching_user: admin)
    results.size.should == 6

    results = search_for("MRB", searching_user: admin)
    results.size.should == 3

    # topic priority
    results = search_for("mrb", topic_id: topic.id)
    results.first.should == user1


    results = search_for("mrb", topic_id: topic2.id)
    results.first.should == user2

    results = search_for("mrb", topic_id: topic3.id)
    results.first.should == user5

    # When searching by name is enabled, it returns the record
    SiteSetting.stubs(:enable_names).returns(true)
    results = search_for("Tarantino")
    results.size.should == 1

    # When searching by name is disabled, it will not return the record
    SiteSetting.stubs(:enable_names).returns(false)
    results = search_for("Tarantino")
    results.size.should == 0

  end

end
