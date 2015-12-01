require 'rails_helper'

describe UserSearch do

  let(:topic)     { Fabricate :topic }
  let(:topic2)    { Fabricate :topic }
  let(:topic3)    { Fabricate :topic }
  let(:topic4)    { Fabricate :topic }
  let(:user1)     { Fabricate :user, username: "mrb", name: "Michael Madsen", last_seen_at: 10.days.ago }
  let(:user2)     { Fabricate :user, username: "mrblue",   name: "Eddie Code", last_seen_at: 9.days.ago }
  let(:user3)     { Fabricate :user, username: "mrorange", name: "Tim Roth", last_seen_at: 8.days.ago }
  let(:user4)     { Fabricate :user, username: "mrpink",   name: "Steve Buscemi",  last_seen_at: 7.days.ago }
  let(:user5)     { Fabricate :user, username: "mrbrown",  name: "Quentin Tarantino", last_seen_at: 6.days.ago }
  let(:user6)     { Fabricate :user, username: "mrwhite",  name: "Harvey Keitel",  last_seen_at: 5.days.ago }
  let!(:inactive) { Fabricate :user, username: "Ghost", active: false }
  let(:admin)     { Fabricate :admin, username: "theadmin" }
  let(:moderator) { Fabricate :moderator, username: "themod" }
  let(:staged)    { Fabricate :staged }

  before do
    ActiveRecord::Base.observers.enable :all

    Fabricate :post, user: user1, topic: topic
    Fabricate :post, user: user2, topic: topic2
    Fabricate :post, user: user3, topic: topic
    Fabricate :post, user: user4, topic: topic
    Fabricate :post, user: user5, topic: topic3
    Fabricate :post, user: user6, topic: topic
    Fabricate :post, user: staged, topic: topic4

    user6.update_attributes(suspended_at: 1.day.ago, suspended_till: 1.year.from_now)
  end

  def search_for(*args)
    UserSearch.new(*args).search
  end

  it 'allows for correct underscore searching' do
    Fabricate(:user, username: 'Under_Score')
    Fabricate(:user, username: 'undertaker')

    expect(search_for("under_sc").length).to eq(1)
    expect(search_for("under_").length).to eq(1)
  end

  # this is a seriously expensive integration test,
  # re-creating this entire test db is too expensive reuse
  it "operates correctly" do
    # normal search
    results = search_for(user1.name.split(" ").first)
    expect(results.size).to eq(1)
    expect(results.first.username).to eq(user1.username)

    # lower case
    results = search_for(user1.name.split(" ").first.downcase)
    expect(results.size).to eq(1)
    expect(results.first).to eq(user1)

    # username
    results = search_for(user4.username)
    expect(results.size).to eq(1)
    expect(results.first).to eq(user4)

    # case insensitive
    results = search_for(user4.username.upcase)
    expect(results.size).to eq(1)
    expect(results.first).to eq(user4)

    # substrings
    # only staff members see suspended users in results
    results = search_for("mr")
    expect(results.size).to eq(5)
    expect(results).not_to include(user6)
    expect(search_for("mr", searching_user: user1).size).to eq(5)

    results = search_for("mr", searching_user: admin)
    expect(results.size).to eq(6)
    expect(results).to include(user6)
    expect(search_for("mr", searching_user: moderator).size).to eq(6)

    results = search_for(user1.username, searching_user: admin)
    expect(results.size).to eq(3)

    results = search_for("MR", searching_user: admin)
    expect(results.size).to eq(6)

    results = search_for("MRB", searching_user: admin, limit: 2)
    expect(results.size).to eq(2)

    # topic priority
    results = search_for(user1.username, topic_id: topic.id)
    expect(results.first).to eq(user1)

    results = search_for(user1.username, topic_id: topic2.id)
    expect(results[1]).to eq(user2)

    results = search_for(user1.username, topic_id: topic3.id)
    expect(results[1]).to eq(user5)

    # When searching by name is enabled, it returns the record
    SiteSetting.enable_names = true
    results = search_for("Tarantino")
    expect(results.size).to eq(1)

    results = search_for("coding")
    expect(results.size).to eq(0)

    results = search_for("z")
    expect(results.size).to eq(0)

    # When searching by name is disabled, it will not return the record
    SiteSetting.enable_names = false
    results = search_for("Tarantino")
    expect(results.size).to eq(0)

    # find an exact match first
    results = search_for("mrB")
    expect(results.first.username).to eq(user1.username)

    # don't return inactive users
    results = search_for(inactive.username)
    expect(results).to be_blank

    # don't return staged users
    results = search_for(staged.username)
    expect(results).to be_blank
  end

end
