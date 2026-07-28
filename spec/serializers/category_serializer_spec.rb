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
          {
            permission_type: CategoryGroup.permission_types[:readonly],
            group_name: group.name,
            group_id: group.id,
          },
          {
            permission_type: CategoryGroup.permission_types[:full],
            group_name: private_group.name,
            group_id: private_group.id,
          },
          {
            permission_type: CategoryGroup.permission_types[:full],
            group_name: user_group.name,
            group_id: user_group.id,
          },
          {
            permission_type: CategoryGroup.permission_types[:readonly],
            group_name: "everyone",
            group_id: Group::AUTO_GROUPS[:everyone],
          },
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

  describe "#allowed_tags" do
    subject(:json) { described_class.new(category, scope: scope, root: false).as_json }

    fab!(:attached_tag) { Fabricate(:tag, name: "category-allowed-tag") }

    before { category.tags << attached_tag }

    context "for a non-editor" do
      let(:scope) { user.guardian }

      it "is not included" do
        expect(json).not_to have_key(:allowed_tags)
      end
    end

    context "for an editor" do
      let(:scope) { admin.guardian }

      it "is included with all tag entries" do
        expect(json[:allowed_tags]).to contain_exactly(
          { id: attached_tag.id, name: attached_tag.name, slug: attached_tag.slug },
        )
      end
    end

    context "when tagging is disabled" do
      let(:scope) { admin.guardian }

      before { SiteSetting.tagging_enabled = false }

      it "is not included" do
        expect(json).not_to have_key(:allowed_tags)
      end
    end
  end

  describe "#allowed_tag_groups" do
    subject(:json) { described_class.new(category, scope: scope, root: false).as_json }

    fab!(:attached_tag_group) { Fabricate(:tag_group, name: "category-allowed-group") }

    before { category.tag_groups << attached_tag_group }

    context "for a non-editor" do
      let(:scope) { user.guardian }

      it "is not included" do
        expect(json).not_to have_key(:allowed_tag_groups)
      end
    end

    context "for an editor" do
      let(:scope) { admin.guardian }

      it "is included with all tag-group names" do
        expect(json[:allowed_tag_groups]).to contain_exactly(attached_tag_group.name)
      end
    end

    context "when tagging is disabled" do
      let(:scope) { admin.guardian }

      before { SiteSetting.tagging_enabled = false }

      it "is not included" do
        expect(json).not_to have_key(:allowed_tag_groups)
      end
    end
  end

  describe "#required_tag_groups" do
    subject(:json) { described_class.new(category, scope: scope, root: false).as_json }

    fab!(:required_tag_group) { Fabricate(:tag_group, name: "category-required-group") }

    fab!(:category_required_tag_group) do
      CategoryRequiredTagGroup.create!(
        category: category,
        tag_group: required_tag_group,
        min_count: 2,
      )
    end

    context "for a non-editor" do
      let(:scope) { user.guardian }

      it "omits the tag-group name from each entry" do
        expect(json[:required_tag_groups]).to eq([{ min_count: 2 }])
      end
    end

    context "for an editor" do
      let(:scope) { admin.guardian }

      it "includes the tag-group name in each entry" do
        expect(json[:required_tag_groups]).to eq([{ name: required_tag_group.name, min_count: 2 }])
      end
    end

    context "when tagging is disabled" do
      let(:scope) { admin.guardian }

      before { SiteSetting.tagging_enabled = false }

      it "is not included" do
        expect(json).not_to have_key(:required_tag_groups)
      end
    end
  end
end
