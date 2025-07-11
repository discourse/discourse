# frozen_string_literal: true

require "rails_helper"

describe DiscourseTemplates::UserExtension do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user)

  describe "can_use_category_templates?" do
    fab!(:discourse_templates_category) { Fabricate(:category_with_definition) }
    fab!(:templates_private_category) do
      Fabricate(:private_category_with_definition, group: Group[:moderators])
    end
    fab!(:templates_private_category2) do
      Fabricate(:private_category_with_definition, group: Group[:admins])
    end

    before { Group.refresh_automatic_groups!(:moderators) }

    it "is false when SiteSetting.discourse_templates_categories is empty" do
      SiteSetting.discourse_templates_categories = ""
      expect(moderator.can_use_templates?).to eq(false)
      expect(user.can_use_templates?).to eq(false)
    end

    context "when only one parent categories is specified" do
      it "is false when SiteSetting.discourse_templates_categories points to category that does not exist" do
        SiteSetting.discourse_templates_categories = "-99999"
        expect(moderator.can_use_templates?).to eq(false)
        expect(user.can_use_templates?).to eq(false)
      end

      it "is true when user can access category" do
        SiteSetting.discourse_templates_categories = discourse_templates_category.id.to_s
        expect(moderator.can_use_templates?).to eq(true)
        expect(user.can_use_templates?).to eq(true)
      end

      it "is false when user can't access category" do
        SiteSetting.discourse_templates_categories = templates_private_category.id.to_s
        expect(user.can_use_templates?).to eq(false)
      end
    end

    context "when multiples parent categories are specified" do
      it "is false when the user cannot access any of the parent categories" do
        SiteSetting.discourse_templates_categories = [
          templates_private_category,
          templates_private_category2,
        ].map(&:id).join("|")
        expect(user.can_use_templates?).to eq(false)
      end

      it "is true when user can access at least one of the parent categories" do
        SiteSetting.discourse_templates_categories = [
          templates_private_category,
          templates_private_category2,
        ].map(&:id).join("|")
        expect(moderator.can_use_templates?).to eq(true)
      end
    end
  end

  describe "can_use_private_templates?" do
    fab!(:other_user) { Fabricate(:user) }

    fab!(:group) do
      group = Fabricate(:group)
      Fabricate(:group_user, group: group, user: user)
      group
    end
    fab!(:other_group) do
      group = Fabricate(:group)
      Fabricate(:group_user, group: group, user: other_user)
      group
    end

    before do
      Group.refresh_automatic_groups!(:moderators)

      SiteSetting.tagging_enabled = true
      SiteSetting.discourse_templates_enable_private_templates = true
      SiteSetting.discourse_templates_groups_allowed_private_templates = ""
      SiteSetting.discourse_templates_private_templates_tags = "private-templates|templates"
    end

    it "is false when SiteSetting.discourse_templates_enable_private_templates is false" do
      SiteSetting.discourse_templates_enable_private_templates = false
      expect(moderator.can_use_private_templates?).to eq(false)
      expect(user.can_use_private_templates?).to eq(false)
    end

    it "is false when SiteSetting.tagging_enabled is false" do
      SiteSetting.tagging_enabled = false
      expect(moderator.can_use_private_templates?).to eq(false)
      expect(user.can_use_private_templates?).to eq(false)
    end

    it "is false when SiteSetting.discourse_templates_private_templates_tags is empty" do
      SiteSetting.discourse_templates_private_templates_tags = ""
      expect(moderator.can_use_private_templates?).to eq(false)
      expect(user.can_use_private_templates?).to eq(false)
    end

    it "is true when settings are configured and user is staff" do
      expect(admin.can_use_private_templates?).to eq(true)
      expect(moderator.can_use_private_templates?).to eq(true)
      expect(user.can_use_private_templates?).to eq(false)
    end

    it "is true when group is 'everyone'" do
      expect(admin.can_use_private_templates?).to eq(true)
      expect(moderator.can_use_private_templates?).to eq(true)
      expect(user.can_use_private_templates?).to eq(false)

      SiteSetting.discourse_templates_groups_allowed_private_templates =
        Group::AUTO_GROUPS[:everyone].to_s
      expect(user.can_use_private_templates?).to eq(true)
    end

    it "only returns true to staff or members of the allowed groups" do
      expect(admin.can_use_private_templates?).to eq(true)
      expect(moderator.can_use_private_templates?).to eq(true)

      SiteSetting.discourse_templates_groups_allowed_private_templates = group.id.to_s
      expect(user.can_use_private_templates?).to eq(true)
      expect(other_user.can_use_private_templates?).to eq(false)

      SiteSetting.discourse_templates_groups_allowed_private_templates = other_group.id.to_s
      expect(user.can_use_private_templates?).to eq(false)
      expect(other_user.can_use_private_templates?).to eq(true)

      SiteSetting.discourse_templates_groups_allowed_private_templates =
        "#{group.id}|#{other_group.id}"
      expect(user.can_use_private_templates?).to eq(true)
      expect(other_user.can_use_private_templates?).to eq(true)
    end
  end
end
