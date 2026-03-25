# frozen_string_literal: true

RSpec.describe "Nested redirect fallback for untracked topics" do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:category)
  fab!(:topic_author, :user)
  fab!(:topic) { Fabricate(:topic, user: topic_author, category: category) }
  fab!(:op) { Fabricate(:post, topic: topic, user: topic_author, post_number: 1) }
  fab!(:reply) { Fabricate(:post, topic: topic, user: topic_author, raw: "A reply to the topic") }

  let(:nested_view) { PageObjects::Pages::NestedView.new }

  before do
    SiteSetting.nested_replies_enabled = true
    sign_in(user)
  end

  # When the nested replies plugin is enabled and a user navigates to a topic
  # that is NOT in the client-side tracking state, the routeWillChange handler
  # in nested-view-redirect.js hits its async fallback path: it aborts the
  # original Ember transition, performs an ajax lookup to determine the
  # category, then resumes navigation.
  #
  # For non-nested topics it must replay the *original* transition via
  # transition.retry() rather than creating a brand-new
  # router.transitionTo("topic.fromParams", slug, topicId). A bare
  # transitionTo always targets topic.fromParams (not topic.fromParamsNear),
  # which drops the nearPost URL segment — losing the user's intended scroll
  # position — and may serialise stale controller query params into the URL.
  #
  # To verify these tests fail without the fix, change the two
  # `transition.retry()` calls in nested-view-redirect.js back to
  # `router.transitionTo("topic.fromParams", slug, topicId)`.

  it "preserves the post number in the URL after the async category check" do
    page.visit("/about")
    expect(page).to have_css("#main-outlet")

    # Clear the client-side tracking state so the topic misses the
    # synchronous lookup and hits the async fallback path.
    page.execute_script(<<~JS)
      const tts = Discourse.lookup("service:topic-tracking-state");
      tts.states.clear();
      require("discourse/lib/url").default.routeTo("/t/#{topic.slug}/#{topic.id}/#{reply.post_number}");
    JS

    expect(page).to have_css("#post_#{reply.post_number}")
    expect(page).to have_current_path("/t/#{topic.slug}/#{topic.id}/#{reply.post_number}")
  end

  it "loads the flat topic view correctly after the async category check" do
    page.visit("/about")
    expect(page).to have_css("#main-outlet")

    page.execute_script(<<~JS)
      const tts = Discourse.lookup("service:topic-tracking-state");
      tts.states.clear();
      require("discourse/lib/url").default.routeTo("/t/#{topic.slug}/#{topic.id}");
    JS

    expect(page).to have_css("#post_1")
    expect(nested_view).to have_no_nested_view
  end
end
