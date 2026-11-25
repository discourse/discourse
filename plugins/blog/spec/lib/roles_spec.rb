# frozen_string_literal: true

RSpec.describe Blog::Roles do
  fab!(:writers, :group)
  fab!(:editors, :group)
  fab!(:publishers, :group)

  let(:staff) { Group::AUTO_GROUPS[:staff] }

  before do
    SiteSetting.blog_contributor_groups = writers.id.to_s
    SiteSetting.blog_editor_groups = editors.id.to_s
    SiteSetting.blog_publisher_groups = "#{publishers.id}|#{staff}"
  end

  describe ".editorial_group_ids" do
    it "is every group the site saved for a role" do
      expect(described_class.contributor_group_ids).to eq([writers.id])
      expect(described_class.editor_group_ids).to eq([editors.id])
      expect(described_class.publisher_group_ids).to eq([publishers.id, staff])
      expect(described_class.editorial_group_ids).to contain_exactly(
        writers.id,
        editors.id,
        publishers.id,
        staff,
      )
    end

    it "is staff alone when the site may not choose its roles, keeping what it saved" do
      SiteSetting.blog_role_groups_enabled = false

      expect(described_class.contributor_group_ids).to eq([staff])
      expect(described_class.editor_group_ids).to eq([staff])
      expect(described_class.publisher_group_ids).to eq([staff])
      expect(described_class.editorial_group_ids).to eq([staff])
      expect(SiteSetting.blog_contributor_groups_map).to eq([writers.id])
    end
  end
end
