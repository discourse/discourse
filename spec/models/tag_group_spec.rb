require 'rails_helper'

describe TagGroup do
  describe '#visible' do
    let(:user1) { Fabricate(:user) }
    let(:user2) { Fabricate(:user) }
    let(:admin) { Fabricate(:admin) }
    let(:moderator) { Fabricate(:moderator) }

    let(:group) { Fabricate(:group) }

    let!(:everyone_tag_group) { Fabricate(:tag_group, name: 'Visible & usable by everyone', tag_names: ['foo-bar']) }
    let!(:visible_tag_group) { Fabricate(:tag_group, name: 'Visible by everyone, usable by staff', tag_names: ['foo']) }
    let!(:staff_only_tag_group) { Fabricate(:tag_group, name: 'Staff only', tag_names: ['bar']) }

    let!(:public_tag_group) { Fabricate(:tag_group, name: 'Public', tag_names: ['public1']) }
    let!(:private_tag_group) { Fabricate(:tag_group, name: 'Private', tag_names: ['privatetag1']) }
    let!(:staff_tag_group) { Fabricate(:tag_group, name: 'Staff Talk', tag_names: ['stafftag1']) }
    let!(:unrestricted_tag_group) { Fabricate(:tag_group, name: 'Unrestricted', tag_names: ['use-anywhere']) }

    let!(:public_category) { Fabricate(:category, name: 'Public Category') }
    let!(:private_category) { Fabricate(:private_category, group: group) }
    let!(:staff_category) { Fabricate(:category, name: 'Secret') }

    let(:everyone) { Group::AUTO_GROUPS[:everyone] }
    let(:staff) { Group::AUTO_GROUPS[:staff] }

    let(:full) { TagGroupPermission.permission_types[:full] }
    let(:readonly) { TagGroupPermission.permission_types[:readonly] }

    before do
      group.add(user2)
      group.save!

      staff_category.set_permissions(admins: :full)
      staff_category.save!

      private_category.set_permissions(staff: :full, group => :full)
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
    end

    it "returns correct groups based on category & tag group permissions" do
      expect(TagGroup.visible(Guardian.new(admin)).pluck(:name)).to match_array(TagGroup.pluck(:name))
      expect(TagGroup.visible(Guardian.new(moderator)).pluck(:name)).to match_array(TagGroup.pluck(:name))

      expect(TagGroup.visible(Guardian.new(user2)).pluck(:name)).to match_array([
        public_tag_group.name, unrestricted_tag_group.name, private_tag_group.name,
        everyone_tag_group.name, visible_tag_group.name,
      ])

      expect(TagGroup.visible(Guardian.new(user1)).pluck(:name)).to match_array([
        public_tag_group.name, unrestricted_tag_group.name, everyone_tag_group.name,
        visible_tag_group.name,
      ])

      expect(TagGroup.visible(Guardian.new(nil)).pluck(:name)).to match_array([
        public_tag_group.name, unrestricted_tag_group.name, everyone_tag_group.name,
        visible_tag_group.name,
      ])
    end
  end
end
