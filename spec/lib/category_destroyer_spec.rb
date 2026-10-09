# frozen_string_literal: true

describe CategoryDestroyer do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user)

  describe ".destroy" do
    it "deletes a category and records the staff action" do
      category = Fabricate(:category, user: admin)
      topic_timer = Fabricate(:topic_timer, category:)

      expect { described_class.destroy(admin.guardian, category) }.to change(Category, :count).by(
        -1,
      ).and change {
              UserHistory.where(
                action: UserHistory.actions[:delete_category],
                acting_user_id: admin.id,
                category_id: category.id,
              ).count
            }.by(1)

      expect(TopicTimer.exists?(topic_timer.id)).to eq(false)
    end

    it "uses the existing category deletion permission" do
      category = Fabricate(:category, user: admin)

      expect do described_class.destroy(user.guardian, category) end.to raise_error(
        Discourse::InvalidAccess,
      )

      expect do described_class.destroy(moderator.guardian, category) end.to raise_error(
        Discourse::InvalidAccess,
      )

      SiteSetting.moderators_manage_categories = true

      described_class.destroy(moderator.guardian, category)

      expect(Category.exists?(category.id)).to eq(false)
    end

    it "does not delete a category that contains topics" do
      category = Fabricate(:category, user: admin)
      Fabricate(:topic, category:)
      category.update!(topic_count: 1)

      expect do described_class.destroy(admin.guardian, category) end.to raise_error(
        Discourse::InvalidAccess,
      )

      expect(Category.exists?(category.id)).to eq(true)
    end

    it "does not delete a category that contains subcategories" do
      category = Fabricate(:category, user: admin)
      Fabricate(:category, parent_category: category)

      expect do described_class.destroy(admin.guardian, category) end.to raise_error(
        Discourse::InvalidAccess,
      )

      expect(Category.exists?(category.id)).to eq(true)
    end
  end
end
