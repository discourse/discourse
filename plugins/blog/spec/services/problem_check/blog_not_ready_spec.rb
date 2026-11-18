# frozen_string_literal: true

RSpec.describe ProblemCheck::BlogNotReady do
  subject(:check) { described_class.new }

  before { enable_blog! }

  it "runs with the other dashboard checks" do
    expect(ProblemCheck.realtime).to include(described_class)
  end

  describe ".call" do
    context "when the blog can publish" do
      it { expect(check).to be_chill_about_it }
    end

    context "when the site requires a login" do
      before { SiteSetting.login_required = true }

      it "links to the setting that blocks publishing" do
        expect(check).to have_a_problem.with_message(
          "The blog cannot publish articles. #{I18n.t("blog.errors.private_site")} <a href='/admin/site_settings/category/all_results?filter=login_required'>Review the setting</a>",
        )
      end
    end

    context "when the blog cannot create its public category" do
      before { Fabricate(:category, name: I18n.t("blog.categories.public")) }

      it do
        reason = I18n.t("blog.errors.category_name_taken", name: I18n.t("blog.categories.public"))
        expect(check).to have_a_problem.with_priority("high").with_message(
          "The blog cannot publish articles. #{reason} <a href='/admin/site_settings/category/all_results?filter=blog_category'>Review the setting</a>",
        )
      end
    end
  end
end
