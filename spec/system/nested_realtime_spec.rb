# frozen_string_literal: true

RSpec.describe "Nested view real-time updates" do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:other_user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:admin)
  fab!(:topic) { Fabricate(:topic, user: user) }
  fab!(:op) { Fabricate(:post, topic: topic, user: user, post_number: 1) }
  fab!(:root_reply) do
    Fabricate(:post, topic: topic, user: Fabricate(:user), raw: "Existing root reply")
  end

  let(:nested_view) { PageObjects::Pages::NestedView.new }

  before do
    SiteSetting.nested_replies_enabled = true
    Fabricate(:nested_topic, topic: topic)
    sign_in(user)
  end

  describe "new root post by another user" do
    it "shows new replies notification banner and loads posts on click" do
      nested_view.visit_nested(topic)
      expect(nested_view).to have_nested_view
      expect(nested_view).to have_root_post(root_reply)

      # Create a root post via PostCreator which triggers MessageBus
      PostCreator.create!(
        other_user,
        topic_id: topic.id,
        raw: "A brand new root reply from another user",
      )

      expect(page).to have_css(".nested-view__new-replies-btn", wait: 10)

      find(".nested-view__new-replies-btn").click

      expect(page).to have_no_css(".nested-view__new-replies-btn")
      expect(page).to have_content("A brand new root reply from another user")
    end
  end

  describe "new child reply by another user" do
    it "shows the new child in the tree" do
      nested_view.visit_nested(topic)
      expect(nested_view).to have_nested_view
      expect(nested_view).to have_root_post(root_reply)

      new_child =
        PostCreator.create!(
          other_user,
          topic_id: topic.id,
          reply_to_post_number: root_reply.post_number,
          raw: "A child reply via message bus",
        )

      expect(page).to have_css(
        "[data-post-number='#{new_child.post_number}']",
        text: "A child reply via message bus",
        wait: 10,
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
      nested_view.visit_nested(topic)
      expect(nested_view).to have_nested_view
      expect(page).to have_content("Legitimate child reply")

      page.execute_script(<<~JS)
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
      JS

      try_until_success(reason: "stale post lookup finishes") do
        expect(page.evaluate_script("window.__stalePostLookupFinished")).to eq(true)
      end

      expect(page).to have_no_content("Wrong topic leaked reply")
    end
  end

  describe "small_action posts" do
    it "does not insert close/open small_actions into the tree" do
      nested_view.visit_nested(topic)
      expect(nested_view).to have_root_post(root_reply)

      small_action = topic.add_small_action(admin, "closed.enabled")

      # A real reply published right after — once it surfaces, the small_action's
      # message bus event has already been delivered (same channel, in order),
      # so we can safely assert it never landed in the tree.
      new_reply =
        PostCreator.create!(other_user, topic_id: topic.id, raw: "Real reply that must show")

      expect(page).to have_css(".nested-view__new-replies-btn", wait: 10)
      find(".nested-view__new-replies-btn").click

      expect(nested_view).to have_root_post(new_reply)
      expect(page).to have_no_css("[data-post-number='#{small_action.post_number}']")
    end
  end
end
