# frozen_string_literal: true

describe CategoryCreator do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user)

  describe ".create" do
    it "creates a category as the authenticated user" do
      category = nil

      expect do
        category =
          described_class.create(
            admin.guardian,
            name: "猫 support",
            description: "Help with **cats**",
            color: "0088CC",
            text_color: "FFFFFF",
          )
      end.to change {
        UserHistory.where(
          action: UserHistory.actions[:create_category],
          acting_user_id: admin.id,
        ).count
      }.by(1)

      expect(category).to be_persisted
      expect(category).to have_attributes(
        name: "猫 support",
        user_id: admin.id,
        color: "0088CC",
        text_color: "FFFFFF",
      )
      expect(category.topic.first_post.raw).to eq("Help with **cats**")
    end

    it "creates a subcategory" do
      parent_category = Fabricate(:category)

      category =
        described_class.create(
          admin.guardian,
          name: "Subcategory",
          parent_category_id: parent_category.id,
        )

      expect(category).to be_persisted
      expect(category.parent_category_id).to eq(parent_category.id)
    end

    it "does not create a subcategory under a deleted category" do
      parent_category = Fabricate(:category)
      parent_category.destroy!

      category =
        described_class.create(
          admin.guardian,
          name: "Orphaned",
          parent_category_id: parent_category.id,
        )

      expect(category).not_to be_persisted
      expect(category.errors.full_messages).to contain_exactly(I18n.t("category.errors.not_found"))
    end

    it "uses the existing category management permission" do
      expect do described_class.create(user.guardian, name: "Not allowed") end.to raise_error(
        Discourse::InvalidAccess,
      )

      expect do
        described_class.create(moderator.guardian, name: "Moderator category")
      end.to raise_error(Discourse::InvalidAccess)

      SiteSetting.moderators_manage_categories = true

      category = described_class.create(moderator.guardian, name: "Moderator category")

      expect(category).to be_persisted
      expect(category.user_id).to eq(moderator.id)
    end

    it "does not let a moderator create a subcategory under a category they cannot see" do
      SiteSetting.moderators_manage_categories = true
      group = Fabricate(:group)
      parent_category = Fabricate(:private_category, group:)

      expect do
        described_class.create(
          moderator.guardian,
          name: "Not visible",
          parent_category_id: parent_category.id,
        )
      end.to raise_error(Discourse::InvalidAccess)

      expect(Category.find_by(name: "Not visible")).to be_nil
    end

    it "rejects descriptions above the category API limit" do
      category =
        described_class.create(
          admin.guardian,
          name: "Long description",
          description: "a" * (described_class::MAX_DESCRIPTION_LENGTH + 1),
        )

      expect(category).not_to be_persisted
      expect(category.errors.full_messages).to contain_exactly(
        I18n.t(
          "category.errors.description_too_long",
          count: described_class::MAX_DESCRIPTION_LENGTH,
        ),
      )
    end

    it "returns model assignment errors without creating a category" do
      category = nil

      expect do
        category =
          described_class.create(admin.guardian, name: "Invalid style", style_type: "not-a-style")
      end.not_to change {
        UserHistory.where(
          action: UserHistory.actions[:create_category],
          acting_user_id: admin.id,
        ).count
      }

      expect(category).not_to be_persisted
      expect(category.errors).to be_present
      expect(Category.find_by(name: "Invalid style")).to be_nil
    end
  end
end
