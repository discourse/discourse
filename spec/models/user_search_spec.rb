# frozen_string_literal: true

require 'rails_helper'

describe UserSearch do

  before_all { SearchIndexer.enable } # Enable for prefabrication
  before { SearchIndexer.enable } # Enable for each test

  fab!(:topic)     { Fabricate :topic }
  fab!(:topic2)    { Fabricate :topic }
  fab!(:topic3)    { Fabricate :topic }
  fab!(:topic4)    { Fabricate :topic }
  fab!(:user1)     { Fabricate :user, username: "mrb", name: "Michael Madsen", last_seen_at: 10.days.ago }
  fab!(:user2)     { Fabricate :user, username: "mrblue",   name: "Eddie Code", last_seen_at: 9.days.ago }
  fab!(:user3)     { Fabricate :user, username: "mrorange", name: "Tim Roth", last_seen_at: 8.days.ago }
  fab!(:user4)     { Fabricate :user, username: "mrpink",   name: "Steve Buscemi",  last_seen_at: 7.days.ago }
  fab!(:user5)     { Fabricate :user, username: "mrbrown",  name: "Quentin Tarantino", last_seen_at: 6.days.ago }
  fab!(:user6)     { Fabricate :user, username: "mrwhite",  name: "Harvey Keitel",  last_seen_at: 5.days.ago }
  fab!(:inactive) { Fabricate :user, username: "Ghost", active: false }
  fab!(:admin)     { Fabricate :admin, username: "theadmin" }
  fab!(:moderator) { Fabricate :moderator, username: "themod" }
  fab!(:staged)    { Fabricate :staged }

  def search_for(*args)
    UserSearch.new(*args).search
  end

  it 'finds users in secure category' do
    group = Fabricate(:group)
    user = Fabricate(:user)
    group.add(user)
    group.save

    category =
      Fabricate(
        :category,
        read_restricted: true,
        user: user
      )

    Fabricate(:category_group, category: category, group: group)

    results = search_for("", category_id: category.id)

    expect(user.username).to eq(results[0].username)
    expect(results.length).to eq(1)

    topic = Fabricate(:topic, category: category)
    _post = Fabricate(:post, user: topic.user, topic: topic)

    results = search_for("", topic_id: topic.id)

    expect(results.length).to eq(2)

    expect(results.map(&:username)).to contain_exactly(
      user.username, topic.user.username
    )
  end

  it 'allows for correct underscore searching' do
    Fabricate(:user, username: 'Under_Score')
    Fabricate(:user, username: 'undertaker')

    expect(search_for("under_sc").length).to eq(1)
    expect(search_for("under_").length).to eq(1)
  end

  it 'allows filtering by group' do
    group = Fabricate(:group)
    sam = Fabricate(:user, username: 'sam')
    _samantha = Fabricate(:user, username: 'samantha')
    group.add(sam)

    results = search_for("sam", groups: [group])
    expect(results.count).to eq(1)
  end

  it 'allows filtering by multiple groups' do
    group_1 = Fabricate(:group)
    sam = Fabricate(:user, username: 'sam')
    group_2 = Fabricate(:group)
    samantha = Fabricate(:user, username: 'samantha')
    group_1.add(sam)
    group_2.add(samantha)

    results = search_for("sam", groups: [group_1, group_2])
    expect(results.count).to eq(2)
  end

  context "with seed data" do
    fab!(:post1) { Fabricate :post, user: user1, topic: topic }
    fab!(:post2) { Fabricate :post, user: user2, topic: topic2 }
    fab!(:post3) { Fabricate :post, user: user3, topic: topic }
    fab!(:post4) { Fabricate :post, user: user4, topic: topic }
    fab!(:post5) { Fabricate :post, user: user5, topic: topic3 }
    fab!(:post6) { Fabricate :post, user: user6, topic: topic }
    fab!(:post7) { Fabricate :post, user: staged, topic: topic4 }

    before { user6.update(suspended_at: 1.day.ago, suspended_till: 1.year.from_now) }

    it "can search by name and username" do
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
    end

    it "handles substring search correctly" do
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
    end

    it "prioritises topic participants" do
      # topic priority
      results = search_for(user1.username, topic_id: topic.id)
      expect(results.first).to eq(user1)

      results = search_for(user1.username, topic_id: topic2.id)
      expect(results[1]).to eq(user2)

      results = search_for(user1.username, topic_id: topic3.id)
      expect(results[1]).to eq(user5)
    end

    it "only searches by name when enabled" do
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
    end

    it "prioritises exact matches" do
      # find an exact match first
      results = search_for("mrB")
      expect(results.first.username).to eq(user1.username)
    end

    it "does not include self, staged or inactive" do
      # don't return inactive users
      results = search_for(inactive.username)
      expect(results).to be_blank

      # don't return staged users
      results = search_for(staged.username)
      expect(results).to be_blank

      results = search_for(staged.username, include_staged_users: true)
      expect(results.first.username).to eq(staged.username)

      results = search_for("", topic_id: topic.id, searching_user: user1)

      # mrb is omitted, mrb is current user
      expect(results.map(&:username)).to eq(["mrpink", "mrorange"])
    end
  end
end
