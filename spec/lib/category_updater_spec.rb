# frozen_string_literal: true

describe CategoryUpdater do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user)

  describe ".update" do
    it "updates category details and keeps the definition topic in sync" do
      category = Fabricate(:category_with_definition, user: admin)
      result = nil

      expect do
        result =
          described_class.update(
            admin.guardian,
            category,
            name: "猫 support",
            description: "Updated **description**",
            color: "0088CC",
            text_color: "FFFFFF",
          )
      end.to change {
        UserHistory.where(
          action: UserHistory.actions[:change_category_settings],
          acting_user_id: admin.id,
          category_id: category.id,
          subject: "name",
        ).count
      }.by(1)

      expect(result).to eq(true)
      expect(category.reload).to have_attributes(
        name: "猫 support",
        color: "0088CC",
        text_color: "FFFFFF",
      )
      expect(category.topic.first_post.reload.raw).to eq("Updated **description**")
    end

    it "moves a category under an existing parent" do
      category = Fabricate(:category, user: admin)
      parent_category = Fabricate(:category)

      result =
        described_class.update(admin.guardian, category, parent_category_id: parent_category.id)

      expect(result).to eq(true)
      expect(category.reload.parent_category_id).to eq(parent_category.id)
    end

    it "does not move a category under a deleted parent" do
      category = Fabricate(:category, user: admin)
      parent_category = Fabricate(:category)
      parent_category.destroy!

      result =
        described_class.update(admin.guardian, category, parent_category_id: parent_category.id)

      expect(result).to eq(false)
      expect(category.errors.full_messages).to contain_exactly(I18n.t("category.errors.not_found"))
      expect(category.reload.parent_category_id).to be_nil
    end

    it "uses the existing category management permission" do
      category = Fabricate(:category, user: admin)

      expect do
        described_class.update(user.guardian, category, name: "Not allowed")
      end.to raise_error(Discourse::InvalidAccess)

      expect do
        described_class.update(moderator.guardian, category, name: "Moderator category")
      end.to raise_error(Discourse::InvalidAccess)

      SiteSetting.moderators_manage_categories = true

      expect(
        described_class.update(moderator.guardian, category, name: "Moderator category"),
      ).to eq(true)
      expect(category.reload.name).to eq("Moderator category")
    end

    it "does not let a moderator update a category they cannot see" do
      SiteSetting.moderators_manage_categories = true
      group = Fabricate(:group)
      category = Fabricate(:private_category, group:)

      expect do
        described_class.update(moderator.guardian, category, name: "Not visible")
      end.to raise_error(Discourse::InvalidAccess)

      expect(category.reload.name).not_to eq("Not visible")
    end

    it "does not let a moderator move a category under a category they cannot see" do
      SiteSetting.moderators_manage_categories = true
      category = Fabricate(:category)
      group = Fabricate(:group)
      parent_category = Fabricate(:private_category, group:)

      expect do
        described_class.update(moderator.guardian, category, parent_category_id: parent_category.id)
      end.to raise_error(Discourse::InvalidAccess)

      expect(category.reload.parent_category_id).to be_nil
    end

    it "rejects descriptions above the category API limit" do
      category = Fabricate(:category, user: admin)
      result = nil

      expect do
        result =
          described_class.update(
            admin.guardian,
            category,
            description: "a" * (described_class::MAX_DESCRIPTION_LENGTH + 1),
          )
      end.not_to change {
        UserHistory.where(
          action: UserHistory.actions[:change_category_settings],
          acting_user_id: admin.id,
          category_id: category.id,
        ).count
      }

      expect(result).to eq(false)
      expect(category.errors.full_messages).to contain_exactly(
        I18n.t(
          "category.errors.description_too_long",
          count: described_class::MAX_DESCRIPTION_LENGTH,
        ),
      )
    end
  end
end
