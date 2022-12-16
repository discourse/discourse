# frozen_string_literal: true

RSpec.describe CategoryGuardian do
  fab!(:admin) { Fabricate(:admin) }
  fab!(:user) { Fabricate(:user) }
  fab!(:can_create_user) { Fabricate(:user) }
  fab!(:category) { Fabricate(:category) }

  describe "can_post_in_category?" do
    it 'returns true for admin and regular user when not restricted category' do
      expect(Guardian.new.can_post_in_category?(category)).to eq(false)
      expect(Guardian.new(admin).can_post_in_category?(category)).to eq(true)
      expect(Guardian.new(user).can_post_in_category?(category)).to eq(true)
    end

    it 'returns true for admin and memebers of priviliged groups for restricted category' do
      category.update!(read_restricted: true)
      group = Fabricate(:group)
      GroupUser.create(group: group, user: user)
      category_group = CategoryGroup.create(group: group, category: category, permission_type: CategoryGroup.permission_types[:readonly])
      expect(Guardian.new.can_post_in_category?(category)).to eq(false)
      expect(Guardian.new(user).can_post_in_category?(category)).to eq(false)
      expect(Guardian.new(admin).can_post_in_category?(category)).to eq(true)

      category_group.update!(permission_type: CategoryGroup.permission_types[:create_post])
      expect(Guardian.new.can_post_in_category?(category)).to eq(false)
      expect(Guardian.new(user).can_post_in_category?(category)).to eq(true)
      expect(Guardian.new(admin).can_post_in_category?(category)).to eq(true)

      category_group.update!(permission_type: CategoryGroup.permission_types[:full])
      expect(Guardian.new.can_post_in_category?(category)).to eq(false)
      expect(Guardian.new(user).can_post_in_category?(category)).to eq(true)
      expect(Guardian.new(admin).can_post_in_category?(category)).to eq(true)
    end
  end
end
