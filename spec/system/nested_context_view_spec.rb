# frozen_string_literal: true

RSpec.describe "Nested context view" do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:topic) { Fabricate(:topic, user: user) }
  fab!(:op) { Fabricate(:post, topic: topic, user: user, post_number: 1) }

  let(:nested_view) { PageObjects::Pages::NestedView.new }
  let(:composer) { PageObjects::Components::Composer.new }

  fab!(:chain_posts) do
    posts = []
    parent = op
    5.times do |i|
      post =
        Fabricate(
          :post,
          topic: topic,
          user: Fabricate(:user),
          raw: "Chain post #{i + 1}",
          reply_to_post_number: parent.post_number,
        )
      posts << post
      parent = post
    end
    posts
  end

  before do
    SiteSetting.nested_replies_enabled = true
    sign_in(user)
  end

  context "with full ancestor context (default)" do
    it "shows the target with ancestor chain" do
      nested_view.visit_nested_context(topic, post_number: chain_posts[3].post_number)

      expect(nested_view).to have_context_view
      expect(nested_view).to have_post(chain_posts[3])
      expect(nested_view).to have_post(chain_posts[0])
      expect(nested_view).to have_post(chain_posts[1])
      expect(nested_view).to have_post(chain_posts[2])
    end

    it "shows 'View full thread' link but not 'View parent context'" do
      nested_view.visit_nested_context(topic, post_number: chain_posts[2].post_number)

      expect(nested_view).to have_view_full_thread_link
      expect(nested_view).to have_no_view_parent_context_link
    end

    it "does not show 'View parent context' for a direct reply to the OP" do
      nested_view.visit_nested_context(topic, post_number: chain_posts[0].post_number)

      expect(nested_view).to have_view_full_thread_link
      expect(nested_view).to have_no_view_parent_context_link
    end

    it "highlights the target post" do
      nested_view.visit_nested_context(topic, post_number: chain_posts[2].post_number)

      expect(nested_view).to have_highlighted_post(chain_posts[2])
    end
  end

  context "with context=0 (no ancestors)" do
    it "renders target at depth 0 with no ancestors" do
      nested_view.visit_nested_context(topic, post_number: chain_posts[3].post_number, context: 0)

      expect(nested_view).to have_context_view
      expect(nested_view).to have_post_at_depth(chain_posts[3], depth: 0)
      expect(nested_view).to have_no_post(chain_posts[0])
      expect(nested_view).to have_no_post(chain_posts[1])
      expect(nested_view).to have_no_post(chain_posts[2])
    end

    it "shows 'View parent context' link" do
      nested_view.visit_nested_context(topic, post_number: chain_posts[3].post_number, context: 0)

      expect(nested_view).to have_view_parent_context_link
    end

    it "clicking 'View parent context' shows full ancestor chain" do
      nested_view.visit_nested_context(topic, post_number: chain_posts[3].post_number, context: 0)
      nested_view.click_view_parent_context

      expect(nested_view).to have_context_view
      expect(nested_view).to have_post(chain_posts[0])
      expect(nested_view).to have_post(chain_posts[1])
      expect(nested_view).to have_post(chain_posts[2])
      expect(nested_view).to have_post(chain_posts[3])
    end
  end

  describe "navigation" do
    it "clicking 'View full thread' returns to root view" do
      nested_view.visit_nested_context(topic, post_number: chain_posts[2].post_number)
      nested_view.click_view_full_thread

      expect(nested_view).to have_nested_view
      expect(nested_view).to have_no_css(".nested-context-view")
    end

    it "full navigation flow: context=0 → parent context → full thread" do
      nested_view.visit_nested_context(topic, post_number: chain_posts[3].post_number, context: 0)

      expect(nested_view).to have_no_post(chain_posts[0])
      expect(nested_view).to have_post_at_depth(chain_posts[3], depth: 0)

      nested_view.click_view_parent_context

      expect(nested_view).to have_post(chain_posts[0])
      expect(nested_view).to have_post(chain_posts[3])

      nested_view.click_view_full_thread

      expect(nested_view).to have_nested_view
      expect(nested_view).to have_no_css(".nested-context-view")
      expect(nested_view).to have_root_post(chain_posts[0])
    end
  end

  context "with deeply nested posts exceeding max_depth" do
    fab!(:deep_chain) do
      posts = []
      parent = op
      13.times do |i|
        post =
          Fabricate(
            :post,
            topic: topic,
            user: Fabricate(:user),
            raw: "Deep chain post #{i + 1}",
            reply_to_post_number: parent.post_number,
          )
        posts << post
        parent = post
      end
      posts
    end

    before { SiteSetting.nested_replies_max_depth = 10 }

    it "deep-link shows target with windowed ancestors within max_depth" do
      nested_view.visit_nested_context(topic, post_number: deep_chain[12].post_number)

      expect(nested_view).to have_context_view
      expect(nested_view).to have_post(deep_chain[12])
      expect(nested_view).to have_post(deep_chain[3])
      expect(nested_view).to have_no_post(deep_chain[1])
    end

    it "shows 'View parent context' when ancestors are truncated" do
      nested_view.visit_nested_context(topic, post_number: deep_chain[12].post_number)

      expect(nested_view).to have_view_parent_context_link
    end

    it "clicking 'View parent context' shifts window up to topmost ancestor" do
      nested_view.visit_nested_context(topic, post_number: deep_chain[12].post_number)
      nested_view.click_view_parent_context

      expect(nested_view).to have_context_view
      expect(nested_view).to have_post(deep_chain[2])
      expect(nested_view).to have_no_post(deep_chain[12])
    end

    it "navigating up from context=0 shows windowed ancestors" do
      nested_view.visit_nested_context(topic, post_number: deep_chain[12].post_number, context: 0)

      expect(nested_view).to have_post_at_depth(deep_chain[12], depth: 0)
      expect(nested_view).to have_no_post(deep_chain[11])

      nested_view.click_view_parent_context

      expect(nested_view).to have_post(deep_chain[12])
      expect(nested_view).to have_post(deep_chain[3])
      expect(nested_view).to have_view_parent_context_link
    end
  end

  describe "pinned posts are not carried into context view" do
    fab!(:root_reply) { Fabricate(:post, topic: topic, user: user, raw: "A pinned root reply") }

    before do
      nested_topic = NestedTopic.find_or_create_by!(topic: topic)
      nested_topic.toggle_pin(root_reply.id)
    end

    it "does not show pinned badge in context view" do
      nested_view.visit_nested(topic)
      expect(nested_view).to have_pinned_post(root_reply)

      nested_view.visit_nested_context(topic, post_number: chain_posts[2].post_number)
      expect(nested_view).to have_context_view
      expect(nested_view).to have_no_pinned_post(root_reply)
    end
  end

  describe "in-route navigation between context views" do
    # Navigating context A → context B in-app (without a full page reload)
    # keeps the same controller/component mounted. When the two chains
    # share a root ancestor, the chain root <NestedPost> would be reused
    # by Glimmer (same post.id key) and its <NestedPostChildren> only
    # reads @preloadedChildren in its constructor — so without a forced
    # rebuild, the inner cascade keeps rendering the *previous* target's
    # chain. routes/nested.js stamps a per-fetch _renderKey on the chain
    # to force a full recreation; these specs guard that.
    it "rebuilds the chain so the new target is visible" do
      nested_view.visit_nested_context(topic, post_number: chain_posts[2].post_number)
      expect(nested_view).to have_post(chain_posts[2])

      nested_view.route_to_nested_context(topic, post_number: chain_posts[4].post_number)

      expect(page).to have_current_path(
        %r{/n/#{Regexp.escape(topic.slug)}/#{topic.id}/#{chain_posts[4].post_number}\b},
      )
      expect(nested_view).to have_post(chain_posts[4])
      expect(nested_view).to have_post(chain_posts[3])
      expect(nested_view).to have_post(chain_posts[0])
    end

    it "re-fires the highlight pulse on the new target after navigation" do
      nested_view.visit_nested_context(topic, post_number: chain_posts[2].post_number)
      expect(nested_view).to have_highlighted_post(chain_posts[2])

      nested_view.route_to_nested_context(topic, post_number: chain_posts[4].post_number)

      expect(nested_view).to have_highlighted_post(chain_posts[4])
    end

    # Notifications produce /t/slug/id/N URLs; topic/from-params.js
    # detects is_nested_view and redirects to /n/.../N. When N is the
    # post we're already viewing, the redirect is a no-op transition —
    # we still need the URL to stay on /n/ (not leak to /t/) and the
    # target to re-highlight via the nested:scroll-to-target appEvent.
    it "keeps the URL on /n/ and re-highlights when /t/ is routed to the post we're already on" do
      nested_view.visit_nested_context(topic, post_number: chain_posts[2].post_number)
      expect(nested_view).to have_highlighted_post(chain_posts[2])

      nested_view.route_to_topic_post(topic, post_number: chain_posts[2].post_number)

      expect(page).to have_current_path(
        %r{/n/#{Regexp.escape(topic.slug)}/#{topic.id}/#{chain_posts[2].post_number}\b},
      )
      expect(nested_view).to have_highlighted_post(chain_posts[2])
    end
  end

  describe "suggested topics" do
    fab!(:other_topic) { Fabricate(:post).topic }

    it "renders suggested topics below the chain" do
      nested_view.visit_nested_context(topic, post_number: chain_posts[2].post_number)

      expect(nested_view).to have_suggested_topics
      expect(nested_view).to have_suggested_topic(other_topic)
    end
  end

  describe "replying in context view" do
    it "stays in nested view after replying" do
      nested_view.visit_nested_context(topic, post_number: chain_posts[1].post_number)
      expect(nested_view).to have_context_view

      nested_view.click_reply_on_post(chain_posts[1])
      expect(composer).to be_opened

      composer.fill_content("Reply from context view")
      composer.submit
      expect(composer).to be_closed

      expect(page).to have_current_path(%r{/n/})
    end
  end
end
