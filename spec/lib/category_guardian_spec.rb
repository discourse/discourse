# frozen_string_literal: true

RSpec.describe CategoryGuardian do
  fab!(:admin) { Fabricate(:admin) }
  fab!(:user) { Fabricate(:user) }
  fab!(:can_create_user) { Fabricate(:user) }

  describe "can_post_in_category?" do
    fab!(:category) { Fabricate(:category) }
    context "when not restricted category" do
      it "returns false for anonymous user" do
        expect(Guardian.new.can_post_in_category?(category)).to eq(false)
      end
      it "returns true for admin" do
        expect(Guardian.new(admin).can_post_in_category?(category)).to eq(true)
      end

      it "returns true for regular user" do
        expect(Guardian.new(user).can_post_in_category?(category)).to eq(true)
      end
    end

    context "when restricted category" do
      fab!(:group) { Fabricate(:group) }
      fab!(:category) do
        Fabricate(
          :private_category,
          group: group,
          permission_type: CategoryGroup.permission_types[:readonly],
        )
      end
      fab!(:group_user) { Fabricate(:group_user, group: group, user: user) }

      it "returns false for anonymous user" do
        expect(Guardian.new.can_post_in_category?(category)).to eq(false)
      end

      it "returns false for member of group with readonly access" do
        expect(Guardian.new(user).can_post_in_category?(category)).to eq(false)
      end

      it "returns false if everyone has readonly access" do
        everyone = Group.find(Group::AUTO_GROUPS[:everyone])
        everyone.add(user)
        category = Fabricate(:category)
        Fabricate(
          :category_group,
          category: category,
          group: everyone,
          permission_type: CategoryGroup.permission_types[:readonly],
        )
        expect(Guardian.new(user).can_post_in_category?(category)).to eq(false)
      end

      it "returns true for admin" do
        expect(Guardian.new(admin).can_post_in_category?(category)).to eq(true)
      end

      it "returns true for member of group with create_post access" do
        category =
          Fabricate(
            :private_category,
            group: group,
            permission_type: CategoryGroup.permission_types[:create_post],
          )
        expect(Guardian.new(user).can_post_in_category?(category)).to eq(true)
      end

      it "returns true for member of group with full access" do
        category =
          Fabricate(
            :private_category,
            group: group,
            permission_type: CategoryGroup.permission_types[:full],
          )
        expect(Guardian.new(user).can_post_in_category?(category)).to eq(true)
      end
    end
  end
end
