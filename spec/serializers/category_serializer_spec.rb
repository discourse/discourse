# frozen_string_literal: true

RSpec.describe CategorySerializer do
  fab!(:user)
  fab!(:admin)
  fab!(:group)
  fab!(:category)
  fab!(:category_moderation_group) { Fabricate(:category_moderation_group, category:, group:) }

  it "includes the reviewable by group name if enabled" do
    SiteSetting.enable_category_group_moderation = true
    json = described_class.new(category, scope: Guardian.new, root: false).as_json
    expect(json[:moderating_group_ids]).to eq([group.id])
  end

  it "doesn't include the reviewable by group name if disabled" do
    SiteSetting.enable_category_group_moderation = false
    json = described_class.new(category, scope: Guardian.new, root: false).as_json
    expect(json[:moderating_group_ids]).to be_blank
  end

  it "includes custom fields" do
    json = described_class.new(category, scope: Guardian.new, root: false).as_json
    expect(json[:custom_fields]).to be_empty

    category.custom_fields["enable_marketplace"] = true
    category.save_custom_fields

    json = described_class.new(category, scope: Guardian.new, root: false).as_json
    expect(json[:custom_fields]).to be_present
  end

  it "does not include the default notification level when there is no user" do
    json = described_class.new(category, scope: Guardian.new, root: false).as_json
    expect(json.key?(:notification_level)).to eq(false)
  end

  describe "user notification level" do
    it "includes the user's notification level" do
      CategoryUser.set_notification_level_for_category(
        user,
        NotificationLevels.all[:watching],
        category.id,
      )
      json = described_class.new(category, scope: Guardian.new(user), root: false).as_json
      expect(json[:notification_level]).to eq(NotificationLevels.all[:watching])
    end
  end

  describe "#group_permissions" do
    fab!(:private_group) do
      Fabricate(:group, visibility_level: Group.visibility_levels[:staff], name: "bbb")
    end

    fab!(:user_group) do
      Fabricate(:group, visibility_level: Group.visibility_levels[:members], name: "ccc").tap do |g|
        g.add(user)
      end
    end

    before do
      group.update!(name: "aaa")

      category.set_permissions(
        :everyone => :readonly,
        group.name => :readonly,
        user_group.name => :full,
        private_group.name => :full,
      )

      category.save!
    end

    it "does not include the attribute for an anon user" do
      json = described_class.new(category, scope: Guardian.new, root: false).as_json

      expect(json[:group_permissions]).to eq(nil)
    end

    it "does not include the attribute for a regular user" do
      json = described_class.new(category, scope: Guardian.new(user), root: false).as_json

      expect(json[:group_permissions]).to eq(nil)
    end

    it "returns the right category group permissions for a user that can edit the category" do
      SiteSetting.moderators_manage_categories = true
      user.update!(moderator: true)

      json = described_class.new(category, scope: Guardian.new(user), root: false).as_json

      expect(json[:group_permissions]).to eq(
        [
          { permission_type: CategoryGroup.permission_types[:readonly], group_name: group.name },
          {
            permission_type: CategoryGroup.permission_types[:full],
            group_name: private_group.name,
          },
          { permission_type: CategoryGroup.permission_types[:full], group_name: user_group.name },
          { permission_type: CategoryGroup.permission_types[:readonly], group_name: "everyone" },
        ],
      )
    end
  end

  describe "available groups" do
    it "not included for a regular user" do
      json = described_class.new(category, scope: Guardian.new(user), root: false).as_json
      expect(json[:available_groups]).to eq(nil)
    end

    it "included for an admin" do
      json = described_class.new(category, scope: Guardian.new(admin), root: false).as_json
      expect(json[:available_groups]).to eq(Group.order(:name).pluck(:name) - ["everyone"])
    end
  end

  describe "name and description" do
    fab!(:category_with_localization) do
      Fabricate(:category, name: "Original Name", description: "Original Description", locale: "en")
    end

    before do
      CategoryLocalization.create!(
        category: category_with_localization,
        locale: "ja",
        name: "日本語名",
        description: "日本語の説明",
      )
    end

    it "returns untranslated name and description for CategorySerializer" do
      json =
        described_class.new(
          category_with_localization,
          scope: Guardian.new(user),
          root: false,
        ).as_json
      expect(json[:name]).to eq("Original Name")
      expect(json[:description]).to eq("Original Description")
    end

    it "returns translated name and description for SiteCategorySerializer when enabled" do
      SiteSetting.content_localization_enabled = true
      user.update!(locale: "ja")
      I18n.with_locale("ja") do
        json =
          SiteCategorySerializer.new(
            category_with_localization,
            scope: Guardian.new(user),
            root: false,
          ).as_json
        expect(json[:name]).to eq("日本語名")
        expect(json[:description]).to eq("日本語の説明")
      end
    end

    it "returns untranslated name and description for BasicCategorySerializer" do
      json =
        BasicCategorySerializer.new(
          category_with_localization,
          scope: Guardian.new(user),
          root: false,
        ).as_json
      expect(json[:name]).to eq("Original Name")
      expect(json[:description]).to eq("Original Description")
    end
  end
end
