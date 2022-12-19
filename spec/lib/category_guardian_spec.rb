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
      fab!(:category) { Fabricate(:category, read_restricted: true) }
      fab!(:group) { Fabricate(:group) }
      fab!(:group_user) { Fabricate(:group_user, group: group, user: user) }
      fab!(:category_group) { Fabricate(:category_group, group: group, category: category, permission_type: CategoryGroup.permission_types[:readonly]) }

      it "returns false for anonymous user" do
        expect(Guardian.new.can_post_in_category?(category)).to eq(false)
      end

      it "returns false for member of group with readonly access" do
        expect(Guardian.new(user).can_post_in_category?(category)).to eq(false)
      end

      it "returns true for admin" do
        expect(Guardian.new(admin).can_post_in_category?(category)).to eq(true)
      end

      it "returns true for member of group with create_post access" do
        category_group.update!(permission_type: CategoryGroup.permission_types[:create_post])
        expect(Guardian.new(admin).can_post_in_category?(category)).to eq(true)
      end

      it "returns true for member of group with full access" do
        category_group.update!(permission_type: CategoryGroup.permission_types[:full])
        expect(Guardian.new(admin).can_post_in_category?(category)).to eq(true)
      end
    end
  end
end
