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
    Fabricate(:nested_topic, topic: topic)
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

    it "shows the desktop context banner with full-topic navigation" do
      nested_view.visit_nested_context(topic, post_number: chain_posts[2].post_number)

      expect(nested_view).to have_context_banner
      expect(nested_view).to have_view_full_thread_link
      expect(nested_view).to have_no_view_parent_context_link

      nested_view.click_view_full_thread

      expect(nested_view).to have_nested_view
      expect(nested_view).to have_no_context_view
      expect(nested_view).to have_root_post(chain_posts[0])
    end

    it "keeps the desktop context banner out of the mobile stacked-root view", mobile: true do
      nested_view.visit_nested_context(topic, post_number: chain_posts[2].post_number)

      expect(nested_view).to have_context_view
      expect(nested_view).to have_mobile_focus
      expect(nested_view).to have_no_context_banner
    end

    it "marks direct post URLs as context routes" do
      nested_view.visit_nested_context(topic, post_number: chain_posts[2].post_number)

      expect(nested_view).to have_context_view
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

    it "keeps the target as the branch root" do
      nested_view.visit_nested_context(topic, post_number: chain_posts[3].post_number, context: 0)

      expect(nested_view).to have_no_post(chain_posts[0])
      expect(nested_view).to have_post_at_depth(chain_posts[3], depth: 0)
    end

    it "offers parent-context navigation" do
      nested_view.visit_nested_context(topic, post_number: chain_posts[3].post_number, context: 0)

      expect(nested_view).to have_context_banner
      expect(nested_view).to have_view_parent_context_link

      nested_view.click_view_parent_context

      expect(nested_view).to have_context_view
      expect(nested_view).to have_post(chain_posts[0])
      expect(nested_view).to have_post(chain_posts[1])
      expect(nested_view).to have_post(chain_posts[2])
      expect(nested_view).to have_post(chain_posts[3])
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

    it "marks truncated contexts as targeted nested views" do
      nested_view.visit_nested_context(topic, post_number: deep_chain[12].post_number)

      expect(nested_view).to have_context_view
    end

    it "context=0 starts at the target even when ancestors would be truncated" do
      nested_view.visit_nested_context(topic, post_number: deep_chain[12].post_number, context: 0)

      expect(nested_view).to have_post_at_depth(deep_chain[12], depth: 0)
      expect(nested_view).to have_no_post(deep_chain[11])
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
    # chain. The topic route stamps a per-fetch _renderKey on the chain
    # to force a full recreation; these specs guard that.
    it "rebuilds the chain so the new target is visible" do
      nested_view.visit_nested_context(topic, post_number: chain_posts[2].post_number)
      expect(nested_view).to have_post(chain_posts[2])

      nested_view.route_to_nested_context(topic, post_number: chain_posts[4].post_number)

      expect(page).to have_current_path(
        %r{/t/#{Regexp.escape(topic.slug)}/#{topic.id}/#{chain_posts[4].post_number}\b},
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
    # detects is_nested_view and keeps the topic route mounted while loading
    # the nested context payload. When N is the post we're already viewing,
    # the target should re-highlight without leaving /t/.
    it "keeps the URL on /t/ and re-highlights when /t/ is routed to the post we're already on" do
      nested_view.visit_nested_context(topic, post_number: chain_posts[2].post_number)
      expect(nested_view).to have_highlighted_post(chain_posts[2])

      nested_view.route_to_topic_post(topic, post_number: chain_posts[2].post_number)

      expect(page).to have_current_path(
        %r{/t/#{Regexp.escape(topic.slug)}/#{topic.id}/#{chain_posts[2].post_number}\b},
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

      expect(page).to have_current_path(%r{/t/})
    end
  end
end
