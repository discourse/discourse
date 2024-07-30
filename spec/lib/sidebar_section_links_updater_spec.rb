# frozen_string_literal: true

RSpec.describe SidebarSectionLinksUpdater do
  fab!(:user)
  fab!(:user2) { Fabricate(:user) }

  describe ".update_category_section_links" do
    fab!(:public_category) { Fabricate(:category) }
    fab!(:public_category2) { Fabricate(:category) }
    fab!(:public_category3) { Fabricate(:category) }

    fab!(:user_category_section_link) do
      Fabricate(:category_sidebar_section_link, linkable: public_category, user: user)
    end

    fab!(:user2_category_section_link) do
      Fabricate(:category_sidebar_section_link, linkable: public_category, user: user2)
    end

    it "deletes all sidebar category section links when category ids provided is blank" do
      described_class.update_category_section_links(user, category_ids: [])

      expect(SidebarSectionLink.exists?(linkable: public_category, user: user)).to eq(false)
      expect(SidebarSectionLink.exists?(linkable: public_category, user: user2)).to eq(true)
    end

    it "updates user's sidebar category section link records to given category ids" do
      expect(
        SidebarSectionLink.where(linkable_type: "Category", user: user).pluck(:linkable_id),
      ).to contain_exactly(public_category.id)

      described_class.update_category_section_links(
        user,
        category_ids: [public_category.id, public_category2.id],
      )

      expect(
        SidebarSectionLink.where(linkable_type: "Category", user: user).pluck(:linkable_id),
      ).to contain_exactly(public_category.id, public_category2.id)
    end

    it "limits the number of category links a user can have" do
      stub_const(SidebarSection, :MAX_USER_CATEGORY_LINKS, 2) do
        described_class.update_category_section_links(
          user,
          category_ids: [public_category.id, public_category2.id, public_category3.id],
        )

        expect(SidebarSectionLink.where(linkable_type: "Category", user: user).count).to eq(2)
      end
    end
  end

  describe ".update_tag_section_links" do
    fab!(:tag)
    fab!(:tag2) { Fabricate(:tag) }

    fab!(:user_tag_section_link) { Fabricate(:tag_sidebar_section_link, linkable: tag, user: user) }

    fab!(:user2_tag_section_link) do
      Fabricate(:tag_sidebar_section_link, linkable: tag, user: user2)
    end

    it "deletes all sidebar tag section links when tag names provided is blank" do
      described_class.update_tag_section_links(user, tag_ids: [])

      expect(SidebarSectionLink.exists?(linkable: tag, user: user)).to eq(false)
      expect(SidebarSectionLink.exists?(linkable: tag, user: user2)).to eq(true)
    end

    it "updates user's sidebar tag section link records to given tag names" do
      expect(
        SidebarSectionLink.where(linkable_type: "Tag", user: user).pluck(:linkable_id),
      ).to contain_exactly(tag.id)

      described_class.update_tag_section_links(user, tag_ids: [tag.id, tag2.id])

      expect(
        SidebarSectionLink.where(linkable_type: "Tag", user: user).pluck(:linkable_id),
      ).to contain_exactly(tag.id, tag2.id)
    end
  end
end
