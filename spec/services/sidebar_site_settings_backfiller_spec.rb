# frozen_string_literal: true

RSpec.describe SidebarSiteSettingsBackfiller do
  fab!(:user) { Fabricate(:user) }
  fab!(:user2) { Fabricate(:user) }
  fab!(:user3) { Fabricate(:user) }
  fab!(:staged_user) { Fabricate(:user, staged: true) }
  fab!(:category) { Fabricate(:category) }
  fab!(:category2) { Fabricate(:category) }
  fab!(:category3) { Fabricate(:category) }
  fab!(:user_category_sidebar_section_link) do
    Fabricate(:category_sidebar_section_link, user: user, linkable: category)
  end
  fab!(:user2_category_sidebar_section_link) do
    Fabricate(:category_sidebar_section_link, user: user2, linkable: category)
  end
  fab!(:user3_category2_sidebar_section_link) do
    Fabricate(:category_sidebar_section_link, user: user3, linkable: category2)
  end

  let!(:category_sidebar_section_link_ids) do
    [
      user_category_sidebar_section_link.id,
      user2_category_sidebar_section_link.id,
      user3_category2_sidebar_section_link.id,
    ]
  end

  fab!(:tag) { Fabricate(:tag) }
  fab!(:tag2) { Fabricate(:tag) }
  fab!(:tag3) { Fabricate(:tag) }
  fab!(:user_tag_sidebar_section_link) do
    Fabricate(:tag_sidebar_section_link, user: user, linkable: tag)
  end
  fab!(:user2_tag_sidebar_section_link) do
    Fabricate(:tag_sidebar_section_link, user: user2, linkable: tag)
  end
  fab!(:user3_tag2_sidebar_section_link) do
    Fabricate(:tag_sidebar_section_link, user: user3, linkable: tag2)
  end

  let!(:tag_sidebar_section_link_ids) do
    [
      user_tag_sidebar_section_link.id,
      user2_tag_sidebar_section_link.id,
      user3_tag2_sidebar_section_link.id,
    ]
  end

  before do
    # Clean up random users created as part of fabrication to make assertions easier to understand.
    User.real.where("id NOT IN (?)", [user.id, user2.id, user3.id, staged_user.id]).delete_all
  end

  it "raises an error when class is initialized with invalid setting name" do
    expect do
      described_class.new("some_random_setting_name", previous_value: "", new_value: "")
    end.to raise_error(RuntimeError, "Invalid setting_name")
  end

  describe "#backfill!" do
    context "for default_navigation_menu_categories setting" do
      it "deletes the right sidebar section link records when categories are removed" do
        backfiller =
          described_class.new(
            "default_navigation_menu_categories",
            previous_value: "#{category.id}|#{category2.id}|#{category3.id}",
            new_value: "#{category3.id}",
          )

        expect do backfiller.backfill! end.to change { SidebarSectionLink.count }.by(-3)

        expect(SidebarSectionLink.exists?(id: category_sidebar_section_link_ids)).to eq(false)
      end

      it "creates the right sidebar section link records when categories are added" do
        backfiller =
          described_class.new(
            "default_navigation_menu_categories",
            previous_value: "#{category.id}|#{category2.id}",
            new_value: "#{category.id}|#{category2.id}|#{category3.id}",
          )

        expect do backfiller.backfill! end.to change { SidebarSectionLink.count }.by(3)

        expect(
          SidebarSectionLink.where(linkable_type: "Category", linkable_id: category3.id).pluck(
            :user_id,
          ),
        ).to contain_exactly(user.id, user2.id, user3.id)
      end

      it "creates the right sidebar section link records when categories are added" do
        backfiller =
          described_class.new(
            "default_navigation_menu_categories",
            previous_value: "",
            new_value: "#{category.id}|#{category2.id}|#{category3.id}",
          )

        expect do backfiller.backfill! end.to change { SidebarSectionLink.count }.by(6)

        expect(
          SidebarSectionLink.where(linkable_type: "Category", linkable_id: category.id).pluck(
            :user_id,
          ),
        ).to contain_exactly(user.id, user2.id, user3.id)

        expect(
          SidebarSectionLink.where(linkable_type: "Category", linkable_id: category2.id).pluck(
            :user_id,
          ),
        ).to contain_exactly(user.id, user2.id, user3.id)

        expect(
          SidebarSectionLink.where(linkable_type: "Category", linkable_id: category3.id).pluck(
            :user_id,
          ),
        ).to contain_exactly(user.id, user2.id, user3.id)
      end

      it "deletes and creates the right sidebar section link records when categories are added and removed" do
        backfiller =
          described_class.new(
            "default_navigation_menu_categories",
            previous_value: "#{category.id}|#{category2.id}",
            new_value: "#{category3.id}",
          )

        original_count = SidebarSectionLink.count

        expect do backfiller.backfill! end.to change {
          SidebarSectionLink.where(linkable_type: "Category", linkable_id: category.id).count
        }.by(-2).and change {
                SidebarSectionLink.where(linkable_type: "Category", linkable_id: category2.id).count
              }.by(-1).and change {
                      SidebarSectionLink.where(
                        linkable_type: "Category",
                        linkable_id: category3.id,
                      ).count
                    }.by(3)

        expect(SidebarSectionLink.count).to eq(original_count) # Net change of 0

        expect(
          SidebarSectionLink.where(linkable_type: "Category", linkable_id: category3.id).pluck(
            :user_id,
          ),
        ).to contain_exactly(user.id, user2.id, user3.id)
      end
    end

    context "for default_navigation_menu_tags setting" do
      it "deletes the right sidebar section link records when tags are removed" do
        backfiller =
          described_class.new(
            "default_navigation_menu_tags",
            previous_value: "#{tag.name}|#{tag2.name}|#{tag3.name}",
            new_value: "#{tag3.name}",
          )

        expect do backfiller.backfill! end.to change { SidebarSectionLink.count }.by(-3)

        expect(SidebarSectionLink.exists?(id: tag_sidebar_section_link_ids)).to eq(false)
      end

      it "creates the right sidebar section link records when tags are added" do
        backfiller =
          described_class.new(
            "default_navigation_menu_tags",
            previous_value: "#{tag.name}|#{tag2.name}",
            new_value: "#{tag.name}|#{tag2.name}|#{tag3.name}",
          )

        expect do backfiller.backfill! end.to change { SidebarSectionLink.count }.by(3)

        expect(
          SidebarSectionLink.where(linkable_type: "Tag", linkable_id: tag3.id).pluck(:user_id),
        ).to contain_exactly(user.id, user2.id, user3.id)
      end

      it "deletes and creates the right sidebar section link records when tags are added and removed" do
        backfiller =
          described_class.new(
            "default_navigation_menu_tags",
            previous_value: "#{tag.name}|#{tag2.name}",
            new_value: "#{tag3.name}",
          )

        original_count = SidebarSectionLink.count

        expect do backfiller.backfill! end.to change {
          SidebarSectionLink.where(linkable_type: "Tag", linkable_id: tag.id).count
        }.by(-2).and change {
                SidebarSectionLink.where(linkable_type: "Tag", linkable_id: tag2.id).count
              }.by(-1).and change {
                      SidebarSectionLink.where(linkable_type: "Tag", linkable_id: tag3.id).count
                    }.by(3)

        expect(SidebarSectionLink.count).to eq(original_count) # net change of 0

        expect(
          SidebarSectionLink.where(linkable_type: "Tag", linkable_id: tag3.id).pluck(:user_id),
        ).to contain_exactly(user.id, user2.id, user3.id)
      end
    end
  end

  describe "#number_of_users_to_backfill" do
    context "for default_navigation_menu_categories setting" do
      it "returns 3 for the user count when a new category for all users is added" do
        backfiller =
          described_class.new(
            "default_navigation_menu_categories",
            previous_value: "",
            new_value: "#{category3.id}",
          )

        expect(backfiller.number_of_users_to_backfill).to eq(3)
      end

      it "returns 2 for the user count when category which 2 users have configured in sidebar is removed" do
        backfiller =
          described_class.new(
            "default_navigation_menu_categories",
            previous_value: "#{category.id}|#{category2.id}",
            new_value: "#{category2.id}",
          )

        expect(backfiller.number_of_users_to_backfill).to eq(2)
      end

      # category, category2 => category2, category3
      it "returns 3 for the user count when a new category is added and a category is removed" do
        backfiller =
          described_class.new(
            "default_navigation_menu_categories",
            previous_value: "#{category.id}|#{category2.id}",
            new_value: "#{category2.id}|#{category3.id}",
          )

        expect(backfiller.number_of_users_to_backfill).to eq(3)
      end

      it "returns 0 for the user count when no new category is added or removed" do
        backfiller =
          described_class.new(
            "default_navigation_menu_categories",
            previous_value: "",
            new_value: "",
          )

        expect(backfiller.number_of_users_to_backfill).to eq(0)
      end
    end

    context "for default_navigation_menu_tags setting" do
      it "returns 3 for the user count when a new tag for all users is added" do
        backfiller =
          described_class.new(
            "default_navigation_menu_tags",
            previous_value: "",
            new_value: "#{tag3.name}",
          )

        expect(backfiller.number_of_users_to_backfill).to eq(3)
      end

      # tag, tag2 => tag2
      it "returns 2 for the user count when tag which 2 users have configured in sidebar is removed" do
        backfiller =
          described_class.new(
            "default_navigation_menu_tags",
            previous_value: "#{tag.name}|#{tag2.name}",
            new_value: "#{tag2.name}",
          )

        expect(backfiller.number_of_users_to_backfill).to eq(2)
      end

      # tag, tag2 => tag2, tag3
      it "returns 3 for the user count when a new tag is added and a tag is removed" do
        backfiller =
          described_class.new(
            "default_navigation_menu_tags",
            previous_value: "#{tag.name}|#{tag2.name}",
            new_value: "#{tag2.name}|#{tag3.name}",
          )

        expect(backfiller.number_of_users_to_backfill).to eq(3)
      end
    end
  end
end
