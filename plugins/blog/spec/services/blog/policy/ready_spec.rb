# frozen_string_literal: true

RSpec.describe Blog::Policy::Ready do
  subject(:policy) { described_class.new(context) }

  fab!(:category)
  fab!(:drafts) { Fabricate(:private_category, group: Group[:staff]) }

  let(:context) { Service::Base::Context.build(guardian: Guardian.new) }

  before { enable_blog!(category:, drafts:) }

  describe "#call" do
    it "passes when the blog settings are complete" do
      expect(policy.call).to eq(true)
    end

    it "fails when a required setting is missing" do
      SiteSetting.blog_drafts_category = ""

      expect(policy.call).to eq(false)
    end
  end

  describe "#reason" do
    it "explains the first problem to fix" do
      SiteSetting.blog_category = ""
      SiteSetting.blog_drafts_category = ""

      expect(policy.reason).to eq(I18n.t("blog.errors.category"))
    end
  end
end
