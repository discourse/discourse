# frozen_string_literal: true

RSpec.describe AccessControlList do
  fab!(:target, :category)
  fab!(:group) { Fabricate(:group, name: "marketing", full_name: "Marketing Team") }
  fab!(:other_group) { Fabricate(:group, name: "support", full_name: "Support Team") }

  describe ".expand_list" do
    it "collapses multiple groups sharing a permission into one record" do
      list = [
        { type: "group", id: group.id, permission: "view" },
        { type: "group", id: other_group.id, permission: "view" },
      ]

      result = described_class.expand_list(list, target, "core")

      expect(result.size).to eq(1)
      entry = result.first
      expect(entry).to match(
        permission: "view",
        allowed_group_ids: contain_exactly(group.id, other_group.id),
        target_type: "Category",
        target_id: target.id,
        owner: "core",
      )
    end

    it "produces a separate record per distinct permission" do
      list = [
        { type: "group", id: group.id, permission: "view" },
        { type: "group", id: group.id, permission: "edit" },
      ]

      result = described_class.expand_list(list, target, "core")

      expect(result.map { |entry| entry[:permission] }).to contain_exactly("view", "edit")
      expect(result.find { |entry| entry[:permission] == "edit" }[:allowed_group_ids]).to(
        contain_exactly(group.id),
      )
    end

    it "accepts a symbol type and a custom owner" do
      list = [{ type: :group, id: group.id, permission: "view" }]

      result = described_class.expand_list(list, target, "chat")

      expect(result.first[:allowed_group_ids]).to contain_exactly(group.id)
      expect(result.first[:owner]).to eq("chat")
    end

    it "returns records that insert_all! can persist as valid acls" do
      list = [
        { type: "group", id: group.id, permission: "view" },
        { type: "group", id: other_group.id, permission: "edit" },
      ]

      described_class.insert_all!(described_class.expand_list(list, target, "core"))

      acls = described_class.where(target: target)
      expect(acls.pluck(:permission)).to contain_exactly("view", "edit")
      expect(acls.find_by(permission: "view").allowed_group_ids).to contain_exactly(group.id)
      expect(acls.find_by(permission: "edit").allowed_group_ids).to contain_exactly(other_group.id)
    end
  end

  describe ".inject_mandatory_acl" do
    let(:mandatory_acl) { { type: :group, id: group.id, permission: "manage" } }

    before do
      target.class.stubs(:has_mandatory_acl?).returns(true)
      target.class.stubs(:mandatory_acl).returns([mandatory_acl])
    end

    it "adds missing mandatory acl entries" do
      flattened_acl = [{ type: "group", id: other_group.id, permission: "view" }]

      result = described_class.inject_mandatory_acl(flattened_acl, target)

      expect(result).to contain_exactly(
        { type: "group", id: other_group.id, permission: "view" },
        mandatory_acl,
      )
    end

    it "does not duplicate mandatory acl entries" do
      flattened_acl = [{ type: "group", id: group.id, permission: "manage" }]

      result = described_class.inject_mandatory_acl(flattened_acl, target)

      expect(result).to contain_exactly({ type: "group", id: group.id, permission: "manage" })
    end
  end

  describe ".flattened_list" do
    fab!(:view_acl) do
      Fabricate(
        :access_control_list_with_groups,
        target: target,
        permission: "view",
        groups: [group],
      )
    end

    fab!(:edit_acl) do
      Fabricate(
        :access_control_list_with_groups,
        target: target,
        permission: "edit",
        groups: [group, other_group],
      )
    end

    before { target.class.stubs(:acl_is_mandatory?).returns(false) }

    it "returns one entry per group per acl with the group metadata" do
      list = described_class.where(target: target).flattened_list

      expect(list.size).to eq(3)

      view_entry = list.find { |entry| entry[:permission] == "view" }
      expect(view_entry).to include(
        type: :group,
        id: group.id,
        permission: "view",
        name: group.name,
        full_name: group.full_name,
        target_type: "Category",
        target_id: target.id,
      )
      expect(view_entry[:metadata]).to eq({ auto_group: false })
    end

    it "emits an entry for every allowed group on an acl" do
      list = described_class.where(target: target, permission: "edit").flattened_list

      expect(list.map { |entry| entry[:id] }).to contain_exactly(group.id, other_group.id)
    end

    it "flags automatic groups in the metadata" do
      Fabricate(
        :access_control_list_with_groups,
        target: target,
        permission: "manage",
        groups: [Group.find(Group::AUTO_GROUPS[:admins])],
      )

      entry = described_class.where(target: target, permission: "manage").flattened_list.first

      expect(entry[:metadata]).to eq({ auto_group: true })
    end

    it "marks mandatory acl entries" do
      target
        .class
        .stubs(:acl_is_mandatory?)
        .with({ type: :group, id: group.id, permission: "view" })
        .returns(true)

      list = described_class.where(target: target).flattened_list

      expect(list.map { |entry| entry.slice(:id, :permission, :mandatory) }).to contain_exactly(
        { id: group.id, permission: "view", mandatory: true },
        { id: group.id, permission: "edit", mandatory: false },
        { id: other_group.id, permission: "edit", mandatory: false },
      )
    end

    it "returns an empty array when there are no acls" do
      expect(described_class.where(target: Fabricate(:category)).flattened_list).to eq([])
    end

    it "does not error if one of the groups is deleted" do
      group.destroy!
      expect { described_class.where(target: target).flattened_list }.not_to raise_error
    end

    context "when for_target is provided" do
      it "stamps every entry with the given target's id and type" do
        list = described_class.where(target: target).flattened_list(for_target: target)

        expect(list.map { |entry| entry[:target_type] }.uniq).to eq(["Category"])
        expect(list.map { |entry| entry[:target_id] }.uniq).to eq([target.id])
      end

      it "raises when the relation spans more than one target" do
        Fabricate(:access_control_list_with_groups, permission: "view", groups: [group])

        expect { described_class.all.flattened_list(for_target: target) }.to raise_error(
          Acl::MixedTargetError,
        )
      end
    end
  end

  describe ".preload_allowed" do
    it "populates allowed_groups_preloaded from allowed_group_ids" do
      acl = Fabricate(:access_control_list_with_groups, groups: [group, other_group])

      loaded = described_class.where(id: acl.id).preload_allowed.first

      expect(loaded.allowed_groups_preloaded.map(&:id)).to contain_exactly(group.id, other_group.id)
    end

    it "loads the allowed groups for the whole relation without an N+1" do
      one = Fabricate(:access_control_list_with_groups, groups: [group])

      queries_for_one =
        track_sql_queries do
          described_class
            .where(id: one.id)
            .preload_allowed
            .each { |acl| acl.allowed_groups_preloaded }
        end

      two = Fabricate(:access_control_list_with_groups, groups: [group])
      three = Fabricate(:access_control_list_with_groups, groups: [other_group])

      queries_for_many =
        track_sql_queries do
          described_class
            .where(id: [one.id, two.id, three.id])
            .preload_allowed
            .each { |acl| acl.allowed_groups_preloaded }
        end

      expect(queries_for_many.size).to eq(queries_for_one.size)
    end
  end

  describe ".matching_user" do
    fab!(:user)
    fab!(:member_group) { Fabricate(:group).tap { |new_group| new_group.add(user) } }
    fab!(:non_member_group, :group)
    fab!(:group_acl) { Fabricate(:access_control_list_with_groups, groups: [member_group]) }
    fab!(:other_group_acl) do
      Fabricate(:access_control_list_with_groups, groups: [non_member_group])
    end
    fab!(:direct_user_acl) { Fabricate(:access_control_list_with_users, users: [user]) }
    fab!(:anonymous_acl) do
      Fabricate(:access_control_list, allowed_group_ids: [Group::AUTO_GROUPS[:anonymous_users]])
    end

    it "matches acls allowing a group the user belongs to" do
      expect(described_class.matching_user(user)).to include(group_acl)
    end

    it "matches acls that allow the user directly" do
      expect(described_class.matching_user(user)).to include(direct_user_acl)
    end

    it "does not match acls for groups the user does not belong to" do
      expect(described_class.matching_user(user)).not_to include(other_group_acl, anonymous_acl)
    end

    it "matches the anonymous group acl for a nil user" do
      expect(described_class.matching_user(nil)).to include(anonymous_acl)
    end

    it "does not match member group acls for a nil user" do
      expect(described_class.matching_user(nil)).not_to include(group_acl, direct_user_acl)
    end
  end
end
