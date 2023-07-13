# frozen_string_literal: true

RSpec.describe TagGroup do
  describe "#visible" do
    fab!(:user1) { Fabricate(:user) }
    fab!(:user2) { Fabricate(:user) }
    fab!(:admin) { Fabricate(:admin) }
    fab!(:moderator) { Fabricate(:moderator) }

    fab!(:group) { Fabricate(:group) }
    fab!(:beta_group) { Fabricate(:group) }

    fab!(:everyone_tag_group) do
      Fabricate(:tag_group, name: "Visible & usable by everyone", tag_names: ["foo-bar"])
    end
    fab!(:visible_tag_group) do
      Fabricate(:tag_group, name: "Visible by everyone, usable by staff", tag_names: ["foo"])
    end
    fab!(:staff_only_tag_group) { Fabricate(:tag_group, name: "Staff only", tag_names: ["bar"]) }
    fab!(:beta_only_tag_group) { Fabricate(:tag_group, name: "Beta only", tag_names: ["beta"]) }

    fab!(:public_tag_group) { Fabricate(:tag_group, name: "Public", tag_names: ["public1"]) }
    fab!(:private_tag_group) { Fabricate(:tag_group, name: "Private", tag_names: ["privatetag1"]) }
    fab!(:staff_tag_group) { Fabricate(:tag_group, name: "Staff Talk", tag_names: ["stafftag1"]) }
    fab!(:unrestricted_tag_group) do
      Fabricate(:tag_group, name: "Unrestricted", tag_names: ["use-anywhere"])
    end

    fab!(:public_category) { Fabricate(:category, name: "Public Category") }
    fab!(:private_category) { Fabricate(:private_category, group: group) }
    fab!(:staff_category) { Fabricate(:category, name: "Secret") }

    let(:everyone) { Group::AUTO_GROUPS[:everyone] }
    let(:staff) { Group::AUTO_GROUPS[:staff] }

    let(:full) { TagGroupPermission.permission_types[:full] }
    let(:readonly) { TagGroupPermission.permission_types[:readonly] }

    before do
      group.add(user2)
      group.save!

      beta_group.add(user1)
      beta_group.save!

      staff_category.set_permissions(admins: :full)
      staff_category.save!

      private_category.set_permissions(:staff => :full, group => :full)
      private_category.save!

      public_category.allowed_tag_groups = [public_tag_group.name]
      private_category.allowed_tag_groups = [private_tag_group.name]
      staff_category.allowed_tag_groups = [staff_tag_group.name]

      everyone_tag_group.permissions = [[everyone, full]]
      everyone_tag_group.save!

      visible_tag_group.permissions = [[everyone, readonly], [staff, full]]
      visible_tag_group.save!

      staff_only_tag_group.permissions = [[staff, full]]
      staff_only_tag_group.save!

      beta_only_tag_group.permissions = [[beta_group, full]]
      beta_only_tag_group.save!
    end

    shared_examples "correct visible tag groups" do
      it "returns correct groups based on category & tag group permissions" do
        expect(TagGroup.visible(Guardian.new(admin)).pluck(:name)).to match_array(
          TagGroup.pluck(:name),
        )
        expect(TagGroup.visible(Guardian.new(moderator)).pluck(:name)).to match_array(
          TagGroup.pluck(:name),
        )

        expect(TagGroup.visible(Guardian.new(user2)).pluck(:name)).to match_array(
          [
            public_tag_group.name,
            unrestricted_tag_group.name,
            private_tag_group.name,
            everyone_tag_group.name,
            visible_tag_group.name,
          ],
        )

        expect(TagGroup.visible(Guardian.new(user1)).pluck(:name)).to match_array(
          [
            public_tag_group.name,
            unrestricted_tag_group.name,
            beta_only_tag_group.name,
            everyone_tag_group.name,
            visible_tag_group.name,
          ],
        )

        expect(TagGroup.visible(Guardian.new(nil)).pluck(:name)).to match_array(
          [
            public_tag_group.name,
            unrestricted_tag_group.name,
            everyone_tag_group.name,
            visible_tag_group.name,
          ],
        )
      end
    end

    include_examples "correct visible tag groups"

    context "with staff-only tag group restricted to a public category" do
      before do
        public_category.allowed_tag_groups = [public_tag_group.name, staff_only_tag_group.name]
        private_category.allowed_tag_groups = [private_tag_group.name, staff_only_tag_group.name]
      end

      include_examples "correct visible tag groups"
    end
  end

  describe "tag_names=" do
    let(:tag_group) { Fabricate(:tag_group) }
    fab!(:tag) { Fabricate(:tag) }

    before { SiteSetting.tagging_enabled = true }

    it "can use existing tags and create new ones" do
      expect { tag_group.tag_names = [tag.name, "new-tag"] }.to change { Tag.count }.by(1)
      expect_same_tag_names(tag_group.reload.tags, [tag, "new-tag"])
    end

    it "removes parent tag as group member" do
      parent = Fabricate(:tag)
      tag_group.tags = [tag, parent]
      tag_group.update!(parent_tag: parent)
      tag_group.reload
      expect_same_tag_names(tag_group.tags, [tag])
      expect_same_tag_names([tag_group.parent_tag], [parent])
    end

    it "removes parent tag as group member when creating the group" do
      parent = Fabricate(:tag)
      tg = Fabricate(:tag_group, tags: [tag, parent], parent_tag: parent)
      expect_same_tag_names(tg.tags, [tag])
      expect_same_tag_names([tg.parent_tag], [parent])
    end

    context "with synonyms" do
      fab!(:synonym) { Fabricate(:tag, name: "synonym", target_tag: tag) }

      it "adds synonyms from base tags too" do
        expect { tag_group.tag_names = [tag.name, "new-tag"] }.to change { Tag.count }.by(1)
        expect_same_tag_names(tag_group.reload.tags, [tag, "new-tag", synonym])
      end

      it "removes tags correctly" do
        tag_group.update!(tag_names: [tag.name])
        tag_group.tag_names = ["new-tag"]
        expect_same_tag_names(tag_group.reload.tags, ["new-tag"])
      end
    end
  end
end
