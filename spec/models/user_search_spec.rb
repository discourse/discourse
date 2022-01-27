# frozen_string_literal: true

require "rails_helper"

describe UserSearch do

  before_all { SearchIndexer.enable } # Enable for prefabrication
  before { SearchIndexer.enable } # Enable for each test

  fab!(:topic)     { Fabricate :topic }
  fab!(:topic2)    { Fabricate :topic }
  fab!(:topic3)    { Fabricate :topic }
  fab!(:topic4)    { Fabricate :topic }
  fab!(:mr_b)      { Fabricate :user, username: "mrb",      name: "Michael Madsen",    last_seen_at: 10.days.ago }
  fab!(:mr_blue)   { Fabricate :user, username: "mrblue",   name: "Eddie Code",        last_seen_at: 9.days.ago }
  fab!(:mr_orange) { Fabricate :user, username: "mrorange", name: "Tim Roth",          last_seen_at: 8.days.ago }
  fab!(:mr_pink)   { Fabricate :user, username: "mrpink",   name: "Steve Buscemi",     last_seen_at: 7.days.ago }
  fab!(:mr_brown)  { Fabricate :user, username: "mrbrown",  name: "Quentin Tarantino", last_seen_at: 6.days.ago }
  fab!(:mr_white)  { Fabricate :user, username: "mrwhite",  name: "Harvey Keitel",     last_seen_at: 5.days.ago }
  fab!(:inactive)  { Fabricate :user, username: "Ghost", active: false }
  fab!(:admin)     { Fabricate :admin, username: "theadmin" }
  fab!(:moderator) { Fabricate :moderator, username: "themod" }
  fab!(:staged)    { Fabricate :staged }

  def search_for(*args)
    # mapping "username" so it's easier to debug
    UserSearch.new(*args).search.map(&:username)
  end

  context "with a secure category" do
    fab!(:user) { Fabricate(:user) }
    fab!(:searching_user) { Fabricate(:user) }
    fab!(:group) { Fabricate(:group) }
    fab!(:category) { Fabricate(:category, read_restricted: true, user: user) }

    before_all do
      Fabricate(:category_group, category: category, group: group)

      group.add(user)
      group.add(searching_user)
      group.save
    end

    it "autocompletes with people in the category" do
      results = search_for("", searching_user: searching_user, category_id: category.id)
      expect(results).to eq [user.username]
    end

    it "will lookup the category from the topic id" do
      topic = Fabricate(:topic, category: category)
      Fabricate(:post, user: topic.user, topic: topic)

      results = search_for("", searching_user: searching_user, topic_id: topic.id)

      expect(results).to eq [topic.user, user].map(&:username)
    end

    it "will raise an error if the user cannot see the category" do
      expect do
        search_for("", searching_user: Fabricate(:user), category_id: category.id)
      end.to raise_error(Discourse::InvalidAccess)
    end

    it "will respect the group member visibility setting" do
      group.update(members_visibility_level: Group.visibility_levels[:owners])
      results = search_for("", searching_user: searching_user, category_id: category.id)
      expect(results).to be_blank

      group.add_owner(searching_user)
      results = search_for("", searching_user: searching_user, category_id: category.id)
      expect(results).to eq [user.username]
    end

  end

  it "allows for correct underscore searching" do
    Fabricate(:user, username: "undertaker")
    under_score = Fabricate(:user, username: "Under_Score")

    expect(search_for("under_sc")).to eq [under_score.username]
    expect(search_for("under_")).to eq [under_score.username]
  end

  it "allows filtering by group" do
    sam = Fabricate(:user, username: "sam")
    Fabricate(:user, username: "samantha")

    group = Fabricate(:group)
    group.add(sam)

    results = search_for("sam", groups: [group])
    expect(results).to eq [sam.username]
  end

  it "allows filtering by multiple groups" do
    sam = Fabricate(:user, username: "sam")
    samantha = Fabricate(:user, username: "samantha")

    group_1 = Fabricate(:group)
    group_1.add(sam)

    group_2 = Fabricate(:group)
    group_2.add(samantha)

    results = search_for("sam", groups: [group_1, group_2])
    expect(results).to eq [sam, samantha].map(&:username)
  end

  context "with seed data" do
    fab!(:post1) { Fabricate :post, user: mr_b, topic: topic }
    fab!(:post2) { Fabricate :post, user: mr_blue, topic: topic2 }
    fab!(:post3) { Fabricate :post, user: mr_orange, topic: topic }
    fab!(:post4) { Fabricate :post, user: mr_pink, topic: topic }
    fab!(:post5) { Fabricate :post, user: mr_brown, topic: topic3 }
    fab!(:post6) { Fabricate :post, user: mr_white, topic: topic }
    fab!(:post7) { Fabricate :post, user: staged, topic: topic4 }
    fab!(:post8) { Fabricate :post, user: mr_brown, topic: topic2, post_type: Post.types[:whisper] }

    before { mr_white.update(suspended_at: 1.day.ago, suspended_till: 1.year.from_now) }

    it "can search by name and username" do
      # normal search
      results = search_for(mr_b.name.split.first)
      expect(results).to eq [mr_b.username]

      # lower case
      results = search_for(mr_b.name.split.first.downcase)
      expect(results).to eq [mr_b.username]

      # username
      results = search_for(mr_pink.username)
      expect(results).to eq [mr_pink.username]

      # case insensitive
      results = search_for(mr_pink.username.upcase)
      expect(results).to eq [mr_pink.username]
    end

    it "handles substring search correctly" do
      results = search_for("mr")
      expect(results).to eq [mr_brown, mr_pink, mr_orange, mr_blue, mr_b].map(&:username)

      results = search_for("mr", searching_user: mr_b)
      expect(results).to eq [mr_brown, mr_pink, mr_orange, mr_blue, mr_b].map(&:username)

      # only staff members see suspended users in results
      results = search_for("mr", searching_user: moderator)
      expect(results).to eq [mr_white, mr_brown, mr_pink, mr_orange, mr_blue, mr_b].map(&:username)

      results = search_for("mr", searching_user: admin)
      expect(results).to eq [mr_white, mr_brown, mr_pink, mr_orange, mr_blue, mr_b].map(&:username)

      results = search_for(mr_b.username, searching_user: admin)
      expect(results).to eq [mr_b, mr_brown, mr_blue].map(&:username)

      results = search_for("MR", searching_user: admin)
      expect(results).to eq [mr_white, mr_brown, mr_pink, mr_orange, mr_blue, mr_b].map(&:username)

      results = search_for("MRB", searching_user: admin, limit: 2)
      expect(results).to eq [mr_b, mr_brown].map(&:username)
    end

    it "prioritises topic participants" do
      results = search_for(mr_b.username, topic_id: topic.id)
      expect(results).to eq [mr_b, mr_brown, mr_blue].map(&:username)

      results = search_for(mr_b.username, topic_id: topic2.id)
      expect(results).to eq [mr_b, mr_blue, mr_brown].map(&:username)

      results = search_for(mr_b.username, topic_id: topic3.id)
      expect(results).to eq [mr_b, mr_brown, mr_blue].map(&:username)
    end

    it "does not reveal whisper users" do
      results = search_for("", topic_id: topic2.id)
      expect(results).to eq [mr_blue.username]
    end

    it "does not include deleted posts users" do
      post4.trash!
      results = search_for("", topic_id: topic.id)
      expect(results).to eq [mr_orange, mr_b].map(&:username)
    end

    it "only reveals topic participants to people with permission" do
      pm_topic = Fabricate(:private_message_post).topic

      # Anonymous, does not have access
      expect do
        search_for("", topic_id: pm_topic.id)
      end.to raise_error(Discourse::InvalidAccess)

      # Random user, does not have access
      expect do
        search_for("", topic_id: pm_topic.id, searching_user: mr_b)
      end.to raise_error(Discourse::InvalidAccess)

      pm_topic.invite(pm_topic.user, mr_b.username)

      results = search_for("", topic_id: pm_topic.id, searching_user: mr_b)
      expect(results).to eq [pm_topic.user.username]
    end

    it "only searches by name when enabled" do
      # When searching by name is enabled, it returns the record
      SiteSetting.enable_names = true
      results = search_for("Tarantino")
      expect(results).to eq [mr_brown.username]

      results = search_for("coding")
      expect(results).to be_blank

      results = search_for("z")
      expect(results).to be_blank

      # When searching by name is disabled, it will not return the record
      SiteSetting.enable_names = false
      results = search_for("Tarantino")
      expect(results).to be_blank
    end

    it "prioritises exact matches" do
      results = search_for("mrB")
      expect(results).to eq [mr_b, mr_brown, mr_blue].map(&:username)
    end

    it "doesn't prioritises exact matches mentions for users who haven't been seen in over a year" do
      abcdef = Fabricate(:user, username: "abcdef", last_seen_at: 2.days.ago)
      abcde  = Fabricate(:user, username: "abcde", last_seen_at: 2.weeks.ago)
      abcd   = Fabricate(:user, username: "abcd", last_seen_at: 2.months.ago)
      abc    = Fabricate(:user, username: "abc", last_seen_at: 2.years.ago)

      results = search_for("abc", topic_id: topic.id)
      expect(results).to eq [abcdef, abcde, abcd, abc].map(&:username)
    end

    it "does not include self, staged or inactive" do
      # don't return inactive users
      results = search_for(inactive.username)
      expect(results).to be_blank

      # don't return staged users
      results = search_for(staged.username)
      expect(results).to be_blank

      results = search_for(staged.username, include_staged_users: true)
      expect(results).to eq [staged.username]

      # mrb is omitted since they're the searching user
      results = search_for("", topic_id: topic.id, searching_user: mr_b)
      expect(results).to eq [mr_pink, mr_orange].map(&:username)
    end

    it "works with last_seen_users option" do
      results = search_for("", last_seen_users: true)

      expect(results).not_to be_blank
      expect(results[0]).to eq("mrbrown")
      expect(results[1]).to eq("mrpink")
      expect(results[2]).to eq("mrorange")
    end
  end
end
