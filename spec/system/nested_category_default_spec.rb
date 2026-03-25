# frozen_string_literal: true

require_relative "../support/nested_replies_helpers"

RSpec.describe "Nested view category default" do
  include NestedRepliesHelpers

  fab!(:admin)
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:category)
  fab!(:nested_category) { Fabricate(:category, name: "Nested Category") }
  fab!(:topic) { Fabricate(:topic, user: user, category: nested_category) }
  fab!(:op) { Fabricate(:post, topic: topic, user: user, post_number: 1) }
  fab!(:reply) { Fabricate(:post, topic: topic, user: Fabricate(:user), raw: "A reply") }

  let(:nested_view) { PageObjects::Pages::NestedView.new }
  let(:category_page) { PageObjects::Pages::Category.new }

  before do
    SiteSetting.nested_replies_enabled = true
    nested_category.category_setting.update!(nested_replies_default: true)
    NestedTopic.create!(topic: topic)
  end

  describe "category settings UI" do
    before { sign_in(admin) }

    it "allows admin to enable nested view default for a category" do
      unchecked_category = Fabricate(:category, name: "Unchecked Category")

      category_page.visit_settings(unchecked_category)

      expect(page).to have_css(".enable-nested-replies-default")
      checkbox = find(".enable-nested-replies-default input[type='checkbox']")
      expect(checkbox).not_to be_checked

      find(".enable-nested-replies-default label.checkbox-label").click
      category_page.save_settings

      expect(page).to have_current_path(%r{/c/#{unchecked_category.slug}})

      unchecked_category.reload
      expect(unchecked_category.nested_replies_default).to eq(true)
    end

    it "shows checkbox as checked when category has nested default enabled" do
      category_page.visit_settings(nested_category)

      checkbox = find(".enable-nested-replies-default input[type='checkbox']")
      expect(checkbox).to be_checked
    end

    context "with simplified category creation" do
      before { SiteSetting.enable_simplified_category_creation = true }

      it "allows admin to enable nested view default for a category" do
        unchecked_category = Fabricate(:category, name: "Unchecked Category")

        category_page.visit_settings(unchecked_category)

        find(
          ".form-kit__control-checkbox-label",
          text: I18n.t("js.nested_replies.category_settings.default_nested_view"),
        ).click
        category_page.save_settings

        unchecked_category.reload
        expect(unchecked_category.nested_replies_default).to eq(true)
      end

      it "shows checkbox as checked when category has nested default enabled" do
        category_page.visit_settings(nested_category)

        checkbox =
          find(
            ".form-kit__control-checkbox-label",
            text: I18n.t("js.nested_replies.category_settings.default_nested_view"),
          ).find(".form-kit__control-checkbox")
        expect(checkbox).to be_checked
      end
    end
  end

  describe "topic redirect" do
    before { sign_in(user) }

    it "redirects to nested view when visiting a topic URL directly" do
      page.visit("/t/#{topic.slug}/#{topic.id}")

      expect(page).to have_current_path(%r{/n/#{topic.slug}/#{topic.id}})
      expect(nested_view).to have_nested_view
    end

    it "redirects to nested view when clicking a topic from the category page" do
      page.visit("/c/#{nested_category.slug}/#{nested_category.id}")
      find(".topic-list-item .raw-topic-link[data-topic-id='#{topic.id}']").click

      expect(page).to have_current_path(%r{/n/#{topic.slug}/#{topic.id}})
      expect(nested_view).to have_nested_view
    end

    it "does not redirect topics in categories without nested default" do
      normal_topic = Fabricate(:topic, user: user, category: category)
      Fabricate(:post, topic: normal_topic, user: user, post_number: 1)

      page.visit("/t/#{normal_topic.slug}/#{normal_topic.id}")

      expect(page).to have_current_path(%r{/t/#{normal_topic.slug}/#{normal_topic.id}})
      expect(nested_view).to have_no_nested_view
    end

    it "respects ?flat=1 to force flat view even in nested-default category" do
      page.visit("/t/#{topic.slug}/#{topic.id}?flat=1")

      expect(page).to have_current_path(%r{/t/#{topic.slug}/#{topic.id}})
      expect(page).to have_current_path(/flat=1/)
      expect(nested_view).to have_no_nested_view
    end

    it "does not redirect to nested when navigating within flat view (e.g. topic timeline)" do
      page.visit("/t/#{topic.slug}/#{topic.id}?flat=1")
      expect(nested_view).to have_no_nested_view

      # Simulate the exact code path the topic timeline uses:
      # topic.urlForPostNumber() → DiscourseURL.routeTo()
      # This exercises the topic-url-for-post-number transformer which rewrites
      # URLs to /nested/ for nested-default categories.
      page.execute_script(<<~JS)
        (function() {
          var topic = Discourse.lookup("controller:topic").model;
          var url = topic.urlForPostNumber(#{reply.post_number});
          require("discourse/lib/url").default.routeTo(url);
        })();
      JS

      expect(page).to have_current_path(%r{/t/#{topic.slug}/#{topic.id}})
      expect(nested_view).to have_no_nested_view
    end
  end
end
