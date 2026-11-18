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

    it "gives new publisher groups access to the public category" do
      blog_category = Fabricate(:category, permissions: { members.id => :full })
      SiteSetting.blog_category = blog_category.id

      SiteSetting.blog_publisher_groups = publishers.id.to_s

      expect(blog_category.reload.category_groups.pluck(:group_id)).to include(publishers.id)
    end
  end

  describe "choosing the public blog category" do
    fab!(:publishers, :group)
    fab!(:members, :group)

    before do
      enable_blog!
      SiteSetting.blog_publisher_groups = publishers.id.to_s
    end

    it "gives the publisher groups access to it" do
      blog_category = Fabricate(:category, permissions: { members.id => :full })

      SiteSetting.blog_category = blog_category.id

      expect(blog_category.reload.category_groups.pluck(:group_id)).to include(publishers.id)
    end
  end
end
