# frozen_string_literal: true

RSpec.describe "Nested replies flat view preference" do
  fab!(:user)
  fab!(:topic)
  fab!(:op) { Fabricate(:post, topic: topic, post_number: 1) }
  fab!(:reply) { Fabricate(:post, topic: topic, raw: "A reply") }
  fab!(:other_topic, :topic)
  fab!(:other_op) { Fabricate(:post, topic: other_topic, post_number: 1) }

  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:nested_view) { PageObjects::Pages::NestedView.new }

  before do
    SiteSetting.nested_replies_enabled = true
    Fabricate(:nested_topic, topic: topic)
    Fabricate(:nested_topic, topic: other_topic)
  end

  it "remembers the flat view across nested topics until switched back" do
    sign_in(user)
    nested_view.visit_nested(topic)
    expect(nested_view).to have_nested_view

    find(".nested-view-toggle.--to-flat").click

    expect(nested_view).to have_no_nested_view
    expect(topic_page).to have_post_number(2)
    expect(user.user_option.reload.prefer_flat_replies).to eq(true)

    topic_page.visit_topic(other_topic)
    expect(nested_view).to have_no_nested_view

    find(".nested-view-toggle.--to-nested").click

    expect(nested_view).to have_nested_view
    expect(user.user_option.reload.prefer_flat_replies).to eq(false)
  end

  it "shows the preference in interface settings" do
    user.user_option.update!(prefer_flat_replies: true)
    sign_in(user)

    page.visit("/u/#{user.username}/preferences/interface")

    expect(page).to have_css(".pref-prefer-flat-replies input[type='checkbox']:checked")
  end

  it "keeps anonymous users on the nested view" do
    nested_view.visit_nested(topic)

    expect(nested_view).to have_nested_view
    expect(page).to have_no_css(".nested-view-toggle")
  end
end
