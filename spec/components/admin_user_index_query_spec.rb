# frozen_string_literal: true

require 'rails_helper'

describe AdminUserIndexQuery do
  def real_users(query)
    query.find_users_query.where('users.id > 0')
  end

  describe "sql order" do
    it "has default" do
      query = ::AdminUserIndexQuery.new({})
      expect(query.find_users_query.to_sql).to match("created_at DESC")
    end

    it "has active order" do
      query = ::AdminUserIndexQuery.new(query: "active")
      expect(query.find_users_query.to_sql).to match("last_seen_at")
    end

    it "can't be injected" do
      query = ::AdminUserIndexQuery.new(order: "wat, no")
      expect(query.find_users_query.to_sql).not_to match("wat, no")
    end

    it "allows custom ordering" do
      query = ::AdminUserIndexQuery.new(order: "trust_level")
      expect(query.find_users_query.to_sql).to match("trust_level DESC")
    end

    it "allows custom ordering asc" do
      query = ::AdminUserIndexQuery.new(order: "trust_level", ascending: true)
      expect(query.find_users_query.to_sql).to match("trust_level ASC")
    end

    it "allows custom ordering for stats wtih default direction" do
      query = ::AdminUserIndexQuery.new(order: "topics_viewed")
      expect(query.find_users_query.to_sql).to match("topics_entered DESC")
    end

    it "allows custom ordering and direction for stats" do
      query = ::AdminUserIndexQuery.new(order: "topics_viewed", ascending: true)
      expect(query.find_users_query.to_sql).to match("topics_entered ASC")
    end
  end

  describe "pagination" do
    it "defaults to the first page" do
      query = ::AdminUserIndexQuery.new({})
      expect(query.find_users.to_sql).to match("OFFSET 0")
    end

    it "offsets by 100 by default for page 2" do
      query = ::AdminUserIndexQuery.new(page: "2")
      expect(query.find_users.to_sql).to match("OFFSET 100")
    end

    it "offsets by limit for page 2" do
      query = ::AdminUserIndexQuery.new(page: "2")
      expect(query.find_users(10).to_sql).to match("OFFSET 10")
    end

    it "ignores negative pages" do
      query = ::AdminUserIndexQuery.new(page: "-2")
      expect(query.find_users.to_sql).to match("OFFSET 0")
    end
  end

  describe "no users with trust level" do

    TrustLevel.levels.each do |key, value|
      it "#{key} returns no records" do
        query = ::AdminUserIndexQuery.new(query: key.to_s)
        expect(real_users(query)).to eq([])
      end
    end

  end

  describe "users with trust level" do

    TrustLevel.levels.each do |key, value|
      it "finds user with trust #{key}" do
        user = Fabricate(:user, trust_level: value)
        Fabricate(:user, trust_level: value + 1)

        query = ::AdminUserIndexQuery.new(query: key.to_s)
        expect(real_users(query)).to eq([user])
      end
    end

  end

  describe 'with a suspected user' do
    fab!(:bot) { Fabricate(:active_user, id: -10, created_at: 1.day.ago) }
    fab!(:regular_user) { Fabricate(:user, created_at: 1.day.ago) }
    fab!(:user_with_bio) { Fabricate(:active_user, created_at: 1.day.ago) }
    fab!(:user_with_website) { Fabricate(:user, created_at: 1.day.ago) }

    before do
      user_with_website.user_profile.website = 'https://example.com'
      user_with_website.user_profile.save!
    end

    it 'finds the suspected user' do
      bot
      regular_user
      user_with_bio
      user_with_website
      query = AdminUserIndexQuery.new(query: 'suspect')
      expect(query.find_users).to contain_exactly(user_with_bio, user_with_website)
    end
  end

  describe "with a pending user" do

    fab!(:user) { Fabricate(:user, active: true, approved: false) }
    fab!(:inactive_user) { Fabricate(:user, approved: false, active: false) }

    it "finds the unapproved user" do
      query = ::AdminUserIndexQuery.new(query: 'pending')
      expect(query.find_users).to include(user)
      expect(query.find_users).not_to include(inactive_user)
    end

    context 'and a suspended pending user' do
      fab!(:suspended_user) { Fabricate(:user, approved: false, suspended_at: 1.hour.ago, suspended_till: 20.years.from_now) }
      it "doesn't return the suspended user" do
        query = ::AdminUserIndexQuery.new(query: 'pending')
        expect(query.find_users).not_to include(suspended_user)
      end
    end

  end

  describe "correct order with nil values" do
    before(:each) do
      Fabricate(:user, email: "test2@example.com", last_emailed_at: 1.hour.ago)
    end

    it "shows nil values first with asc" do
      users = ::AdminUserIndexQuery.new(order: "last_emailed", ascending: true).find_users

      expect(users.where('users.id > -2').count).to eq(2)
      expect(users.where('users.id > -2').order('users.id asc').first.username).to eq("system")
      expect(users.first.last_emailed_at).to eq(nil)
    end

    it "shows nil values last with desc" do
      users = ::AdminUserIndexQuery.new(order: "last_emailed").find_users

      expect(users.where('users.id > -2').count).to eq(2)
      expect(users.first.last_emailed_at).to_not eq(nil)
    end

  end

  describe "with an admin user" do

    fab!(:user) { Fabricate(:user, admin: true) }
    fab!(:user2) { Fabricate(:user, admin: false) }

    it "finds the admin" do
      query = ::AdminUserIndexQuery.new(query: 'admins')
      expect(real_users(query)).to eq([user])
    end

  end

  describe "with a moderator" do

    fab!(:user) { Fabricate(:user, moderator: true) }
    fab!(:user2) { Fabricate(:user, moderator: false) }

    it "finds the moderator" do
      query = ::AdminUserIndexQuery.new(query: 'moderators')
      expect(real_users(query)).to eq([user])
    end

  end

  describe "with a silenced user" do

    fab!(:user) { Fabricate(:user, silenced_till: 1.year.from_now) }
    fab!(:user2) { Fabricate(:user) }

    it "finds the silenced user" do
      query = ::AdminUserIndexQuery.new(query: 'silenced')
      expect(real_users(query)).to eq([user])
    end

  end

  describe "with a staged user" do

    fab!(:user) { Fabricate(:user, staged: true) }
    fab!(:user2) { Fabricate(:user, staged: false) }

    it "finds the staged user" do
      query = ::AdminUserIndexQuery.new(query: 'staged')
      expect(real_users(query)).to eq([user])
    end

  end

  describe "filtering" do

    context "exact email bypass" do
      it "can correctly bypass expensive ilike query" do
        user = Fabricate(:user, email: 'sam@Sam.com')

        query = AdminUserIndexQuery.new(filter: 'Sam@sam.com').find_users_query
        expect(query.count).to eq(1)
        expect(query.first.id).to eq(user.id)

        expect(query.to_sql.downcase).not_to include("ilike")
      end

      it "can correctly bypass expensive ilike query" do
        user = Fabricate(:user, email: 'sam2@Sam.com')

        query = AdminUserIndexQuery.new(email: 'Sam@sam.com').find_users_query
        expect(query.count).to eq(0)
        expect(query.to_sql.downcase).not_to include("ilike")

        query = AdminUserIndexQuery.new(email: 'Sam2@sam.com').find_users_query
        expect(query.first.id).to eq(user.id)
        expect(query.count).to eq(1)
        expect(query.to_sql.downcase).not_to include("ilike")

      end
    end

    context "by email fragment" do

      before(:each) { Fabricate(:user, email: "test1@example.com") }

      it "matches the email" do
        query = ::AdminUserIndexQuery.new(filter: " est1")
        expect(query.find_users.count()).to eq(1)
      end

      it "matches the email using any case" do
        query = ::AdminUserIndexQuery.new(filter: "Test1\t")
        expect(query.find_users.count()).to eq(1)
      end

    end

    context "by username fragment" do

      before(:each) { Fabricate(:user, username: "test_user_1") }

      it "matches the username" do
        query = ::AdminUserIndexQuery.new(filter: "user\n")
        expect(query.find_users.count).to eq(1)
      end

      it "matches the username using any case" do
        query = ::AdminUserIndexQuery.new(filter: "\r\nUser")
        expect(query.find_users.count).to eq(1)
      end
    end

    context "by ip address fragment" do

      fab!(:user) { Fabricate(:user, ip_address: "117.207.94.9") }

      it "matches the ip address" do
        query = ::AdminUserIndexQuery.new(filter: " 117.207.94.9 ")
        expect(query.find_users.count()).to eq(1)
      end

    end

  end
end
