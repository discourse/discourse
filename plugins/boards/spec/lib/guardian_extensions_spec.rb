# frozen_string_literal: true

RSpec.describe Boards::GuardianExtensions do
  fab!(:admin)
  fab!(:creator, :user)
  fab!(:reader, :user)
  fab!(:writer, :user)
  fab!(:outsider, :user)
  fab!(:member) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:read_group, :group)
  fab!(:write_group, :group)
  let(:anonymous_guardian) { Guardian.new }

  before do
    enable_current_plugin

    read_group.add(reader)
    write_group.add(writer)
  end

  describe "#can_read_boards_board?" do
    it "denies read to non-editors when no read or write groups are set" do
      board = Boards::Board.create!(name: "Roadmap", slug: "roadmap")

      expect(reader.guardian.can_read_boards_board?(board)).to be_falsey
      expect(outsider.guardian.can_read_boards_board?(board)).to be_falsey
      expect(anonymous_guardian.can_read_boards_board?(board)).to be_falsey
    end

    it "does not allow anonymous users to read when read_group_ids are set" do
      board = Boards::Board.create!(name: "Roadmap", slug: "roadmap")
      Fabricate(
        :access_control_list_with_groups,
        target: board,
        permission: "view",
        groups: [read_group],
      )
      expect(anonymous_guardian.can_read_boards_board?(board)).to be_falsey
    end

    it "grants read through read groups" do
      board = Boards::Board.create!(name: "Roadmap", slug: "roadmap")
      Fabricate(
        :access_control_list_with_groups,
        target: board,
        permission: "view",
        groups: [read_group],
      )

      expect(reader.guardian.can_read_boards_board?(board)).to be_truthy
      expect(outsider.guardian.can_read_boards_board?(board)).to be_falsey
    end

    it "returns true when the user can write" do
      board = Boards::Board.create!(name: "Operations", slug: "operations")
      Fabricate(
        :access_control_list_with_groups,
        target: board,
        permission: "edit",
        groups: [write_group],
      )

      expect(writer.guardian.can_read_boards_board?(board)).to be_truthy
    end

    it "grants public read to anonymous and logged in users via the anonymous and trust level 0 groups" do
      board = Boards::Board.create!(name: "Public", slug: "public")
      Fabricate(
        :access_control_list,
        target: board,
        permission: "view",
        allowed_group_ids: [
          Group::AUTO_GROUPS[:anonymous_users],
          Group::AUTO_GROUPS[:logged_in_users],
        ],
      )

      expect(anonymous_guardian.can_read_boards_board?(board)).to be_truthy
      expect(member.guardian.can_read_boards_board?(board)).to be_truthy
    end

    it "grants members-only read via logged in users while excluding anonymous users" do
      board = Boards::Board.create!(name: "Members", slug: "members")
      Fabricate(
        :access_control_list,
        target: board,
        permission: "view",
        allowed_group_ids: [Group::AUTO_GROUPS[:logged_in_users]],
      )

      expect(member.guardian.can_read_boards_board?(board)).to be_truthy
      expect(anonymous_guardian.can_read_boards_board?(board)).to be_falsey
    end
  end

  describe "#can_write_boards_board?" do
    it "grants write through write groups" do
      board = Boards::Board.create!(name: "Operations", slug: "operations")
      Fabricate(
        :access_control_list_with_groups,
        target: board,
        permission: "edit",
        groups: [write_group],
      )

      expect(writer.guardian.can_write_boards_board?(board)).to eq(true)
      expect(outsider.guardian.can_write_boards_board?(board)).to eq(false)
    end

    it "does not grant write to admins without an edit or manage ACL" do
      board = Boards::Board.create!(name: "Engineering", slug: "engineering")

      expect(admin.guardian.can_write_boards_board?(board)).to eq(false)
    end

    it "does not allow creator special priveleges to write if they are not in a write group" do
      board = Boards::Board.create!(name: "Support", slug: "support", created_by_id: creator.id)
      Fabricate(
        :access_control_list_with_groups,
        target: board,
        permission: "edit",
        groups: [write_group],
      )

      expect(creator.guardian.can_write_boards_board?(board)).to eq(false)

      write_group.add(creator)
      creator.reload

      expect(creator.guardian.can_write_boards_board?(board)).to eq(true)
    end
  end
end
