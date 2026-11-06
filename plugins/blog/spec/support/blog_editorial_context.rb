# frozen_string_literal: true

RSpec.shared_context "with blog editorial setup" do
  fab!(:acting_user, :admin)
  fab!(:category)
  fab!(:writers, :group)
  fab!(:writer) { Fabricate(:user, groups: [writers], refresh_auto_groups: true) }
  fab!(:drafts) { Fabricate(:private_category, group: Group[:staff]) }

  let(:dependencies) { { guardian: acting_user.guardian } }
  let(:publication) { Blog::Publication.for_topic(topic) }

  before do
    enable_blog!(category:, drafts:)
    SiteSetting.blog_contributor_groups = writers.id.to_s
    drafts.set_permissions(:staff => :full, writers.name => :full)
    drafts.save!
  end
end
