# frozen_string_literal: true

describe DiscourseTemplates::GuardianExtension do
  fab!(:moderator) do
    moderator = Fabricate(:moderator)
    Group.refresh_automatic_groups!(:moderators)
    moderator
  end
  fab!(:user)
  fab!(:other_user, :user)
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
  fab!(:discourse_templates_category, :category_with_definition)
  fab!(:templates_private_category) do
    Fabricate(:private_category_with_definition, group: Group[:moderators])
  end
  fab!(:templates_private_category2) do
    Fabricate(:private_category_with_definition, group: Group[:admins])
  end

  describe "can_use_templates?" do
    let!(:guardian) { Guardian.new(user) }

    before do
      SiteSetting.discourse_templates_categories = discourse_templates_category.id.to_s
      SiteSetting.tagging_enabled = true
      SiteSetting.discourse_templates_enable_private_templates = true
      SiteSetting.discourse_templates_groups_allowed_private_templates =
        "#{group.id}|#{other_group.id}"
      SiteSetting.discourse_templates_private_templates_tags = "templates"
    end

    it "returns true only when both can_use_category_templates? and can_use_private_templates? are true" do
      expect(guardian.can_use_category_templates?).to eq(true)
      expect(guardian.can_use_private_templates?).to eq(true)
      expect(guardian.can_use_templates?).to eq(true)
    end

    it "returns true only when only can_use_category_templates? is true" do
      SiteSetting.discourse_templates_enable_private_templates = false

      expect(guardian.can_use_category_templates?).to eq(true)
      expect(guardian.can_use_private_templates?).to eq(false)
      expect(guardian.can_use_templates?).to eq(true)
    end

    it "returns true only when only can_use_private_templates? is true" do
      SiteSetting.discourse_templates_categories = ""

      expect(guardian.can_use_category_templates?).to eq(false)
      expect(guardian.can_use_private_templates?).to eq(true)
      expect(guardian.can_use_templates?).to eq(true)
    end

    it "returns false only when both can_use_category_templates? and can_use_private_templates? are false" do
      SiteSetting.discourse_templates_enable_private_templates = false
      SiteSetting.discourse_templates_categories = ""

      expect(guardian.can_use_category_templates?).to eq(false)
      expect(guardian.can_use_private_templates?).to eq(false)
      expect(guardian.can_use_templates?).to eq(false)
    end
  end

  describe "can_use_category_templates??" do
    it "is false for anonymous users" do
      expect(Guardian.new.can_use_category_templates?).to eq(false)
    end

    context "when only one parent categories is specified" do
      it "is true when user can access category" do
        SiteSetting.discourse_templates_categories = discourse_templates_category.id.to_s
        expect(Guardian.new(moderator).can_use_category_templates?).to eq(true)
        expect(Guardian.new(user).can_use_category_templates?).to eq(true)

        SiteSetting.discourse_templates_categories = templates_private_category.id.to_s
        expect(Guardian.new(moderator).can_use_category_templates?).to eq(true)
      end

      it "is false when user can't access category" do
        SiteSetting.discourse_templates_categories = templates_private_category.id.to_s
        expect(Guardian.new(user).can_use_category_templates?).to eq(false)
      end
    end

    context "when multiple parent categories are specified" do
      it "is true when user can access at least one category" do
        SiteSetting.discourse_templates_categories = [
          templates_private_category,
          templates_private_category2,
        ].map(&:id).join("|")
        expect(Guardian.new(moderator).can_use_category_templates?).to eq(true)
      end

      it "is false when user can't access any category" do
        SiteSetting.discourse_templates_categories = [
          templates_private_category,
          templates_private_category2,
        ].map(&:id).join("|")
        expect(Guardian.new(user).can_use_category_templates?).to eq(false)
      end
    end
  end

  describe "can_use_private_templates?" do
    before do
      SiteSetting.tagging_enabled = true
      SiteSetting.discourse_templates_enable_private_templates = true
      SiteSetting.discourse_templates_groups_allowed_private_templates = ""
      SiteSetting.discourse_templates_private_templates_tags = "private-templates|templates"
    end

    it "is false for anonymous users" do
      expect(Guardian.new.can_use_private_templates?).to eq(false)
    end

    it "is true for staff" do
      expect(Guardian.new(moderator).can_use_private_templates?).to eq(true)
      expect(Guardian.new(user).can_use_private_templates?).to eq(false)
    end

    it "only returns true to staff or members of the allowed groups" do
      expect(Guardian.new(moderator).can_use_private_templates?).to eq(true)

      SiteSetting.discourse_templates_groups_allowed_private_templates = group.id.to_s
      expect(Guardian.new(user).can_use_private_templates?).to eq(true)
      expect(Guardian.new(other_user).can_use_private_templates?).to eq(false)

      SiteSetting.discourse_templates_groups_allowed_private_templates = other_group.id.to_s
      expect(Guardian.new(user).can_use_private_templates?).to eq(false)
      expect(Guardian.new(other_user).can_use_private_templates?).to eq(true)

      SiteSetting.discourse_templates_groups_allowed_private_templates =
        "#{group.id}|#{other_group.id}"
      expect(Guardian.new(user).can_use_private_templates?).to eq(true)
      expect(Guardian.new(other_user).can_use_private_templates?).to eq(true)
    end
  end
end
