# frozen_string_literal: true

RSpec.describe Blog do
  describe "changing a blog role group setting" do
    fab!(:editors, :group)
    fab!(:publishers, :group)
    fab!(:members, :group)

    before { enable_blog! }

    it "updates the drafts category's access when it exists" do
      drafts = Blog::EnsureDraftsCategory.call![:category]

      SiteSetting.blog_editor_groups = editors.id.to_s

      expect(drafts.reload.category_groups.pluck(:group_id)).to contain_exactly(
        Group::AUTO_GROUPS[:staff],
        editors.id,
      )
    end

    it "does not create a drafts category" do
      expect { SiteSetting.blog_editor_groups = editors.id.to_s }.not_to change { Category.count }
      expect(SiteSetting.blog_drafts_category).to be_blank
    end

    it "lets new publisher groups start topics in the public category without removing access" do
      blog_category = Fabricate(:category)
      blog_category.set_permissions(members.name => :full, :everyone => :readonly)
      blog_category.save!
      SiteSetting.blog_category = blog_category.id

      SiteSetting.blog_publisher_groups = publishers.id.to_s

      expect(
        blog_category.reload.category_groups.pluck(:group_id, :permission_type),
      ).to contain_exactly(
        [members.id, CategoryGroup.permission_types[:full]],
        [Group::AUTO_GROUPS[:everyone], CategoryGroup.permission_types[:readonly]],
        [publishers.id, CategoryGroup.permission_types[:full]],
      )
    end
  end
end
