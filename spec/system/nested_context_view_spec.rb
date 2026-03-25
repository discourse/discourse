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
