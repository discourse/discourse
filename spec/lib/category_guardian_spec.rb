# frozen_string_literal: true

RSpec.describe CategoryGuardian do
  fab!(:admin) { Fabricate(:admin) }
  fab!(:user) { Fabricate(:user) }
  fab!(:can_create_user) { Fabricate(:user) }
  fab!(:category) { Fabricate(:category) }

  describe "can_post_in_category?" do
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

  describe "topics_need_approval?" do
    fab!(:reviewable_group) { Fabricate(:group) }

    it "returns false when admin" do
      expect(Guardian.new(admin).topics_need_approval?(category)).to eq(false)
    end

    it "returns the value of require_topic_approval when group moderation is off" do
      SiteSetting.enable_category_group_moderation = false
      category.custom_fields[Category::REQUIRE_TOPIC_APPROVAL] = false
      category.save!

      expect(Guardian.new(user).topics_need_approval?(category)).to eq(false)

      category.custom_fields[Category::REQUIRE_TOPIC_APPROVAL] = true
      category.save!

      expect(Guardian.new(user).topics_need_approval?(category)).to eq(true)
    end

    it "returns the value of require_topic_approval when group moderation is on and there are no groups set" do
      SiteSetting.enable_category_group_moderation = true
      category.reviewable_by_group_id = nil

      category.custom_fields[Category::REQUIRE_TOPIC_APPROVAL] = false
      category.save!

      expect(Guardian.new(user).topics_need_approval?(category)).to eq(false)

      category.custom_fields[Category::REQUIRE_TOPIC_APPROVAL] = true
      category.save!

      expect(Guardian.new(user).topics_need_approval?(category)).to eq(true)
    end

    it "returns false when group moderation is on and the user is in the reviewable group" do
      SiteSetting.enable_category_group_moderation = true
      category.custom_fields[Category::REQUIRE_TOPIC_APPROVAL] = true
      category.reviewable_by_group_id = reviewable_group.id
      category.save!
      Fabricate(:group_user, group: reviewable_group, user: user)

      expect(Guardian.new(user).topics_need_approval?(category)).to eq(false)
    end

    it "returns true when group moderation is on and the user is not in the reviewable group" do
      SiteSetting.enable_category_group_moderation = true
      category.custom_fields[Category::REQUIRE_TOPIC_APPROVAL] = false
      category.reviewable_by_group_id = Fabricate(:group).id
      category.save!

      expect(Guardian.new(user).topics_need_approval?(category)).to eq(true)
    end
  end
end
