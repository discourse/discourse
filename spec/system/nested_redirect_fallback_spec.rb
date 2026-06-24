# frozen_string_literal: true

RSpec.describe "Topic route fallback for untracked nested-capable topics" do
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

  # When nested replies is enabled, topic/from-params.js needs the topic's
  # category metadata before it can resolve topic.is_nested_view and choose
  # between flat and nested rendering. When the topic is NOT in client-side
  # tracking state, the category lookup may be async, exercising a fallback path.
  #
  # These tests verify the fallback preserves the post number in the URL
  # (so the user's scroll position isn't lost) and that non-nested topics
  # still load the flat view correctly.

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
