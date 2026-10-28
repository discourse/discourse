# frozen_string_literal: true

RSpec.describe "Nested replies flat view preference" do
  fab!(:user)
  fab!(:topic)
  fab!(:op) { Fabricate(:post, topic: topic, post_number: 1) }
  fab!(:replies) { Fabricate.times(12, :post, topic: topic) }
  fab!(:other_topic, :topic)
  fab!(:other_op) { Fabricate(:post, topic: other_topic, post_number: 1) }

  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:nested_view) { PageObjects::Pages::NestedView.new }

  before do
    SiteSetting.nested_replies_enabled = true
    Fabricate(:nested_topic, topic: topic)
    Fabricate(:nested_topic, topic: other_topic)
  end

  def flat_view_set_up?
    page.evaluate_script(<<~JS)
      (() => {
        const topicController = Discourse.lookup("controller:topic");
        return (
          Discourse.lookup("controller:nested").topic === null &&
          Discourse.lookup("service:screen-track")._topicController === topicController
        );
      })()
    JS
  end

  it "remembers the flat view across nested topics until switched back" do
    SiteSetting.show_topic_map_in_topics_without_replies = false
    sign_in(user)
    nested_view.visit_nested(topic)
    expect(nested_view).to have_nested_view

    find(".nested-view-toggle.--to-flat").click

    expect(nested_view).to have_no_nested_view
    expect(topic_page).to have_post_number(2)
    expect(flat_view_set_up?).to eq(true)
    expect(user.user_option.reload.prefer_flat_replies).to eq(true)

    topic_page.visit_topic(other_topic)
    expect(nested_view).to have_no_nested_view
    expect(page).to have_no_css(".nested-view-toggle")

    find(".topic-footer-main-buttons .toggle-nested-view").click

    expect(nested_view).to have_nested_view
    expect(user.user_option.reload.prefer_flat_replies).to eq(false)
  end

  it "keeps the post being read when switching views" do
    sign_in(user)
    nested_view.visit_nested_context(topic, post_number: 3)
    expect(nested_view).to have_context_view

    find(".nested-view-toggle.--to-flat").click

    expect(nested_view).to have_no_nested_view
    expect(page).to have_current_path("/t/#{topic.slug}/#{topic.id}/3", ignore_query: true)
    expect(topic_page).to have_post_number(3)
    expect(flat_view_set_up?).to eq(true)
  end

  it "shows the preference in interface settings" do
    user.user_option.update!(prefer_flat_replies: true)
    sign_in(user)

    page.visit("/u/#{user.username}/preferences/interface")

    expect(page).to have_css(".pref-prefer-flat-replies input[type='checkbox']:checked")
  end

  it "remembers an anonymous user's flat view in the browser" do
    SiteSetting.show_topic_map_in_topics_without_replies = false
    nested_view.visit_nested(topic)
    expect(nested_view).to have_nested_view

    find(".nested-view-toggle.--to-flat").click

    expect(nested_view).to have_no_nested_view
    expect(topic_page).to have_post_number(2)

    topic_page.visit_topic(other_topic)
    page.refresh
    expect(nested_view).to have_no_nested_view

    find("#topic-footer-buttons .toggle-nested-view").click

    expect(nested_view).to have_nested_view
  end
end
