# frozen_string_literal: true

RSpec.describe "Nested view real-time updates", native_playwright: true do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:other_user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:admin)
  fab!(:topic) { Fabricate(:topic, user: user) }
  fab!(:op) { Fabricate(:post, topic: topic, user: user, post_number: 1) }
  fab!(:root_reply) do
    Fabricate(:post, topic: topic, user: Fabricate(:user), raw: "Existing root reply")
  end

  let(:nested_view) { browser_page.locator(".nested-view:visible") }
  let(:activity_log) { browser_page.locator(".nested-activity-log-modal") }

  before do
    SiteSetting.nested_replies_enabled = true
    Fabricate(:nested_topic, topic: topic)
    sign_in(user)
  end

  private

  def visit_nested
    browser_page
      .goto("/t/#{topic.slug}/#{topic.id}")
      .tap { SystemBrowserBootstrap.wait_for(browser_page) }
  end

  describe "new root post by another user" do
    it "shows new replies notification banner and loads posts on click" do
      visit_nested
      expect(nested_view).to PlaywrightMatchers.be_visible
      expect(
        browser_page.locator(
          ".nested-view__roots [data-post-number='#{root_reply.post_number}']:visible",
        ),
      ).to PlaywrightMatchers.have_count(1)

      # Create a root post via PostCreator which triggers MessageBus
      PostCreator.create!(
        other_user,
        topic_id: topic.id,
        raw: "A brand new root reply from another user",
      )

      expect(
        browser_page.locator(".nested-view__new-replies-btn:visible"),
      ).to PlaywrightMatchers.have_count(1, timeout: 10_000)

      browser_page.locator(".nested-view__new-replies-btn:visible").click

      expect(
        browser_page.locator(".nested-view__new-replies-btn:visible"),
      ).to PlaywrightMatchers.have_count(0)
      expect(browser_page.locator("body")).to PlaywrightMatchers.contain_text(
        "A brand new root reply from another user",
        useInnerText: true,
      )
    end
  end

  describe "new child reply by another user" do
    it "shows the new child in the tree" do
      visit_nested
      expect(nested_view).to PlaywrightMatchers.be_visible
      expect(
        browser_page.locator(
          ".nested-view__roots [data-post-number='#{root_reply.post_number}']:visible",
        ),
      ).to PlaywrightMatchers.have_count(1)

      new_child =
        PostCreator.create!(
          other_user,
          topic_id: topic.id,
          reply_to_post_number: root_reply.post_number,
          raw: "A child reply via message bus",
        )

      expect(
        browser_page.locator("[data-post-number='#{new_child.post_number}']:visible"),
      ).to PlaywrightMatchers.contain_text(
        "A child reply via message bus",
        useInnerText: true,
        timeout: 10_000,
      )
    end
  end

  describe "stale events from another topic" do
    fab!(:other_topic) { Fabricate(:topic, user: other_user, title: "Topic with stale replies") }
    fab!(:other_op) { Fabricate(:post, topic: other_topic, user: other_user, post_number: 1) }
    fab!(:other_root) do
      Fabricate(:post, topic: other_topic, user: other_user, raw: "Other topic root reply")
    end
    fab!(:other_sibling) do
      Fabricate(:post, topic: other_topic, user: other_user, raw: "Other topic sibling reply")
    end
    fab!(:wrong_topic_reply) do
      Fabricate(
        :post,
        topic: other_topic,
        user: other_user,
        raw: "Wrong topic leaked reply",
        reply_to_post_number: other_root.post_number,
      )
    end
    fab!(:existing_child) do
      Fabricate(
        :post,
        topic: topic,
        user: user,
        raw: "Legitimate child reply",
        reply_to_post_number: root_reply.post_number,
      )
    end

    before { Fabricate(:nested_topic, topic: other_topic) }

    it "ignores stale created events for posts from a different topic" do
      visit_nested
      expect(nested_view).to PlaywrightMatchers.be_visible
      expect(browser_page.locator("body")).to PlaywrightMatchers.contain_text(
        "Legitimate child reply",
        useInnerText: true,
      )

      browser_page.evaluate(<<~JS)
        () => {
        window.__stalePostLookupFinished = false;
        jQuery(document).one("ajaxComplete", (_event, _xhr, settings) => {
          if (settings.url.includes("/posts/#{wrong_topic_reply.id}.json")) {
            window.__stalePostLookupFinished = true;
          }
        });
        Discourse.lookup("controller:nested")._onMessage({
          type: "created",
          id: #{wrong_topic_reply.id},
          user_id: #{other_user.id}
        });
        }
      JS

      browser_page.wait_for_function(
        "() => window.__stalePostLookupFinished === true",
        timeout: Capybara.default_max_wait_time * 1000,
      )

      expect(browser_page.locator("body")).not_to PlaywrightMatchers.contain_text(
        "Wrong topic leaked reply",
        useInnerText: true,
      )
    end
  end

  describe "small_action posts" do
    it "adds the activity link and updates the modal without inserting the action into the tree" do
      visit_nested
      expect(
        browser_page.locator(
          ".nested-view__roots [data-post-number='#{root_reply.post_number}']:visible",
        ),
      ).to PlaywrightMatchers.have_count(1)
      expect(
        browser_page.locator(".nested-view__activity-link:visible"),
      ).to PlaywrightMatchers.have_count(0)

      small_action = topic.add_small_action(admin, "closed.enabled")

      expect(
        browser_page.locator(".nested-view__activity-link:visible"),
      ).to PlaywrightMatchers.have_count(1, timeout: 10_000)
      expect(
        browser_page.locator("[data-post-number='#{small_action.post_number}']:visible"),
      ).to PlaywrightMatchers.have_count(0)

      browser_page.locator(".nested-view__activity-link:visible").click
      expect(
        activity_log.locator("[data-post-id='#{small_action.id}']:visible"),
      ).to PlaywrightMatchers.have_count(1)

      revised = PostRevisor.new(small_action)
      revised.revise!(admin, raw: "Updated through the message bus")

      expect(
        activity_log.locator("[data-post-id='#{small_action.id}']:visible"),
      ).to PlaywrightMatchers.contain_text("Updated through the message bus", useInnerText: true)
    end
  end
end
