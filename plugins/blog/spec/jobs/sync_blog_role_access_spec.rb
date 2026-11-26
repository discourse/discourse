# frozen_string_literal: true

RSpec.describe Jobs::SyncBlogRoleAccess do
  fab!(:writers, :group)
  fab!(:outsiders, :group)

  let(:drafts) { Blog::EnsureDraftsCategory.call![:category] }
  let(:staff) { Group::AUTO_GROUPS[:staff] }

  before do
    enable_blog!
    SiteSetting.blog_contributor_groups = writers.id.to_s
    drafts.set_permissions(staff => :full, writers.id => :full, outsiders.id => :full)
    drafts.save!
  end

  describe "#execute" do
    it "limits the drafts category to the groups that hold a role" do
      described_class.new.execute(nil)

      expect(drafts.reload.category_groups.pluck(:group_id)).to contain_exactly(staff, writers.id)
    end

    it "leaves the category alone while the blog is disabled" do
      SiteSetting.blog_enabled = false

      described_class.new.execute(nil)

      expect(drafts.reload.category_groups.pluck(:group_id)).to contain_exactly(
        staff,
        writers.id,
        outsiders.id,
      )
    end
  end
end
