# frozen_string_literal: true

RSpec.describe SidebarSectionLinksUpdater do
  fab!(:user) { Fabricate(:user) }
  fab!(:user2) { Fabricate(:user) }

  describe ".update_category_section_links" do
    fab!(:public_category) { Fabricate(:category) }
    fab!(:public_category2) { Fabricate(:category) }
    fab!(:group) { Fabricate(:group) }
    fab!(:secured_category) { Fabricate(:private_category, group: group) }

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

    it "updates user's sidebar category section link records to given category ids except for category restricted to user" do
      expect(
        SidebarSectionLink.where(linkable_type: "Category", user: user).pluck(:linkable_id),
      ).to contain_exactly(public_category.id)

      described_class.update_category_section_links(
        user,
        category_ids: [public_category2.id, secured_category.id],
      )

      expect(
        SidebarSectionLink.where(linkable_type: "Category", user: user).pluck(:linkable_id),
      ).to contain_exactly(public_category2.id)

      group.add(user)

      described_class.update_category_section_links(
        user,
        category_ids: [public_category2.id, secured_category.id],
      )

      expect(
        SidebarSectionLink.where(linkable_type: "Category", user: user).pluck(:linkable_id),
      ).to contain_exactly(public_category2.id, secured_category.id)
    end
  end

  describe ".update_tag_section_links" do
    fab!(:tag) { Fabricate(:tag) }
    fab!(:tag2) { Fabricate(:tag) }
    fab!(:hidden_tag) { Fabricate(:tag) }
    fab!(:staff_tag_group) do
      Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: [hidden_tag.name])
    end

    fab!(:user_tag_section_link) { Fabricate(:tag_sidebar_section_link, linkable: tag, user: user) }
    fab!(:user2_tag_section_link) do
      Fabricate(:tag_sidebar_section_link, linkable: tag, user: user2)
    end

    it "deletes all sidebar tag section links when tag names provided is blank" do
      described_class.update_tag_section_links(user, tag_names: [])

      expect(SidebarSectionLink.exists?(linkable: tag, user: user)).to eq(false)
      expect(SidebarSectionLink.exists?(linkable: tag, user: user2)).to eq(true)
    end

    it "updates user's sidebar tag section link records to given tag names except for tags not visible to user" do
      expect(
        SidebarSectionLink.where(linkable_type: "Tag", user: user).pluck(:linkable_id),
      ).to contain_exactly(tag.id)

      described_class.update_tag_section_links(user, tag_names: [tag2.name, hidden_tag.name])

      expect(
        SidebarSectionLink.where(linkable_type: "Tag", user: user).pluck(:linkable_id),
      ).to contain_exactly(tag2.id)

      user.update!(admin: true)

      described_class.update_tag_section_links(user, tag_names: [tag2.name, hidden_tag.name])

      expect(
        SidebarSectionLink.where(linkable_type: "Tag", user: user).pluck(:linkable_id),
      ).to contain_exactly(tag2.id, hidden_tag.id)
    end
  end
end
