# frozen_string_literal: true

require "rails_helper"

describe Guardian do
  before { SiteSetting.data_explorer_enabled = true }

  def make_query(group_ids = [])
    query =
      DiscourseDataExplorer::Query.create!(
        name: "Query number #{Fabrication::Sequencer.sequence("query-id", 1)}",
        sql: "SELECT 1",
      )

    group_ids.each { |group_id| query.query_groups.create!(group_id: group_id) }

    query
  end

  let(:user) { build(:user) }
  let(:admin) { build(:admin) }
  fab!(:group)

  describe "#user_is_a_member_of_group?" do
    it "is true when the user is an admin" do
      expect(Guardian.new(admin).user_is_a_member_of_group?(group)).to eq(true)
    end

    it "is true when the user is not an admin, but is a member of the group" do
      group.add(user)

      expect(Guardian.new(user).user_is_a_member_of_group?(group)).to eq(true)
    end

    it "is false when the user is not an admin, and is not a member of the group" do
      expect(Guardian.new(user).user_is_a_member_of_group?(group)).to eq(false)
    end
  end

  describe "#group_and_user_can_access_query?" do
    it "is true if the user is an admin" do
      expect(Guardian.new(admin).group_and_user_can_access_query?(group, make_query)).to eq(true)
    end

    it "is true if the user is a member of the group, and query contains the group id" do
      query = make_query(["#{group.id}"])
      group.add(user)

      expect(Guardian.new(user).group_and_user_can_access_query?(group, query)).to eq(true)
    end

    it "is false if the query does not contain the group id" do
      group.add(user)

      expect(Guardian.new(user).group_and_user_can_access_query?(group, make_query)).to eq(false)
    end

    it "is false if the user is not member of the group" do
      query = make_query(["#{group.id}"])

      expect(Guardian.new(user).group_and_user_can_access_query?(group, query)).to eq(false)
    end
  end
end
