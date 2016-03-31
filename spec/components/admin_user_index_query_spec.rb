require 'rails_helper'
require_dependency 'admin_user_index_query'

describe AdminUserIndexQuery do
  def real_users_count(query)
    query.find_users_query.where('users.id > 0').count
  end

  describe "sql order" do
    it "has default" do
      query = ::AdminUserIndexQuery.new({})
      expect(query.find_users_query.to_sql).to match("created_at DESC")
    end

    it "has active order" do
      query = ::AdminUserIndexQuery.new({ query: "active" })
      expect(query.find_users_query.to_sql).to match("last_seen_at")
    end
  end

  describe "no users with trust level" do

    TrustLevel.levels.each do |key, value|
      it "#{key} returns no records" do
        query = ::AdminUserIndexQuery.new({ query: key.to_s })
        expect(real_users_count(query)).to eq(0)
      end
    end

  end

  describe "users with trust level" do

    TrustLevel.levels.each do |key, value|
      it "finds user with trust #{key}" do
        Fabricate(:user, trust_level: TrustLevel.levels[key])
        query = ::AdminUserIndexQuery.new({ query: key.to_s })
        expect(real_users_count(query)).to eq(1)
      end
    end

  end

  describe "with a pending user" do

    let!(:user) { Fabricate(:user, approved: false) }

    it "finds the unapproved user" do
      query = ::AdminUserIndexQuery.new({ query: 'pending' })
      expect(query.find_users.count).to eq(1)
    end

    context 'and a suspended pending user' do
      let!(:suspended_user) { Fabricate(:user, approved: false, suspended_at: 1.hour.ago, suspended_till: 20.years.from_now) }
      it "doesn't return the suspended user" do
        query = ::AdminUserIndexQuery.new({ query: 'pending' })
        expect(query.find_users.count).to eq(1)
      end
    end

  end

  describe "with an admin user" do

    let!(:user) { Fabricate(:user, admin: true) }

    it "finds the admin" do
      query = ::AdminUserIndexQuery.new({ query: 'admins' })
      expect(real_users_count(query)).to eq(1)
    end

  end

  describe "with a moderator" do

    let!(:user) { Fabricate(:user, moderator: true) }

    it "finds the moderator" do
      query = ::AdminUserIndexQuery.new({ query: 'moderators' })
      expect(real_users_count(query)).to eq(1)
    end

  end

  describe "with a blocked user" do

    let!(:user) { Fabricate(:user, blocked: true) }

    it "finds the blocked user" do
      query = ::AdminUserIndexQuery.new({ query: 'blocked' })
      expect(query.find_users.count).to eq(1)
    end

  end

  describe "filtering" do

    context "by email fragment" do

      before(:each) { Fabricate(:user, email: "test1@example.com") }

      it "matches the email" do
        query = ::AdminUserIndexQuery.new({ filter: "est1" })
        expect(query.find_users.count()).to eq(1)
      end

      it "matches the email using any case" do
        query = ::AdminUserIndexQuery.new({ filter: "Test1" })
        expect(query.find_users.count()).to eq(1)
      end

    end

    context "by username fragment" do

      before(:each) { Fabricate(:user, username: "test_user_1") }

      it "matches the username" do
        query = ::AdminUserIndexQuery.new({ filter: "user" })
        expect(query.find_users.count).to eq(1)
      end

      it "matches the username using any case" do
        query = ::AdminUserIndexQuery.new({ filter: "User" })
        expect(query.find_users.count).to eq(1)
      end
    end

    context "by ip address fragment" do

      let!(:user) { Fabricate(:user, ip_address: "117.207.94.9") }

      it "matches the ip address" do
        query = ::AdminUserIndexQuery.new({ filter: "117.207.94.9" })
        expect(query.find_users.count()).to eq(1)
      end

    end

  end
end
