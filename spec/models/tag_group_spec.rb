require 'rails_helper'

describe TagGroup do
  describe '#allowed' do
    let(:user1) { Fabricate(:user) }
    let(:user2) { Fabricate(:user) }
    let(:admin) { Fabricate(:admin) }
    let(:moderator) { Fabricate(:moderator) }

    let(:group) { Fabricate(:group) }

    let!(:public_tag_group) { Fabricate(:tag_group, name: 'Public', tag_names: ['public1']) }
    let!(:private_tag_group) { Fabricate(:tag_group, name: 'Private', tag_names: ['privatetag1']) }
    let!(:staff_tag_group) { Fabricate(:tag_group, name: 'Staff Talk', tag_names: ['stafftag1']) }
    let!(:unrestricted_tag_group) { Fabricate(:tag_group, name: 'Unrestricted', tag_names: ['use-anywhere']) }

    let!(:public_category) { Fabricate(:category, name: 'Public Category') }
    let!(:private_category) { Fabricate(:private_category, group: group) }
    let(:staff_category) { Fabricate(:category, name: 'Secret') }

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
    end

    it "returns correct groups based on category permissions" do
      expect(TagGroup.allowed(Guardian.new(admin)).pluck(:name)).to match_array(TagGroup.pluck(:name))
      expect(TagGroup.allowed(Guardian.new(moderator)).pluck(:name)).to match_array(TagGroup.pluck(:name))
      expect(TagGroup.allowed(Guardian.new(user2)).pluck(:name)).to match_array([public_tag_group.name, unrestricted_tag_group.name, private_tag_group.name])
      expect(TagGroup.allowed(Guardian.new(user1)).pluck(:name)).to match_array([public_tag_group.name, unrestricted_tag_group.name])
      expect(TagGroup.allowed(Guardian.new(nil)).pluck(:name)).to match_array([public_tag_group.name, unrestricted_tag_group.name])
    end
  end
end
