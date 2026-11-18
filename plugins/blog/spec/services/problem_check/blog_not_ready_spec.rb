# frozen_string_literal: true

RSpec.describe ProblemCheck::BlogNotReady do
  subject(:check) { described_class.new }

  before { enable_blog! }

  it "runs with the other dashboard checks" do
    expect(ProblemCheck.realtime).to include(described_class)
  end

  describe ".call" do
    fab!(:drafts) { Fabricate(:private_category, group: Group[:staff]) }

    before { SiteSetting.blog_drafts_category = drafts.id }

    context "when the blog can publish" do
      it { expect(check).to be_chill_about_it }
    end

    context "when nobody has used the blog" do
      before do
        SiteSetting.blog_drafts_category = ""
        SiteSetting.login_required = true
      end

      it { expect(check).to be_chill_about_it }
    end

    context "when the blog has an article but no drafts category" do
      before do
        SiteSetting.blog_drafts_category = ""
        SiteSetting.login_required = true
        Blog::Publication.create!(topic: Fabricate(:topic), path: "/article")
      end

      it { expect(check).to have_a_problem }
    end

    context "when the drafts category is open to everyone" do
      before do
        drafts.set_permissions(everyone: :full)
        drafts.save!
      end

      it "explains the problem without linking to a setting" do
        expect(check).to have_a_problem.with_message(
          "The blog cannot publish articles. #{I18n.t("blog.errors.drafts_category_public")}",
        )
      end
    end

    context "when the site requires a login" do
      before { SiteSetting.login_required = true }

      it "links to the setting that blocks publishing" do
        expect(check).to have_a_problem.with_priority("high").with_message(
          "The blog cannot publish articles. #{I18n.t("blog.errors.private_site")} <a href='/admin/site_settings/category/all_results?filter=login_required'>Review the setting</a>",
        )
      end
    end
  end
end
