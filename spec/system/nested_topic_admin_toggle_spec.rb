# frozen_string_literal: true

require_relative "../support/nested_replies_helpers"

RSpec.describe "Nested replies topic admin toggle" do
  include NestedRepliesHelpers

  fab!(:admin)
  fab!(:topic) { Fabricate(:topic, user: admin) }
  fab!(:op) { Fabricate(:post, topic: topic, user: admin, post_number: 1) }
  fab!(:reply) { Fabricate(:post, topic: topic, user: Fabricate(:user), raw: "A reply") }

  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:nested_view) { PageObjects::Pages::NestedView.new }

  before do
    SiteSetting.nested_replies_enabled = true
    sign_in(admin)
  end

  it "enables nested replies from the flat view and routes to nested" do
    topic_page.visit_topic(topic)

    topic_page.click_admin_menu_button
    find(".topic-admin-nested-replies").click

    expect(page).to have_current_path(%r{/n/#{topic.slug}/#{topic.id}})
    expect(nested_view).to have_nested_view

    topic.reload
    expect(topic.reload.nested_topic).to be_present
  end

  it "disables nested replies from the nested view and routes to flat" do
    NestedTopic.create!(topic: topic)

    nested_view.visit_nested(topic)
    nested_view.open_admin_menu
    find(".topic-admin-nested-replies").click

    expect(page).to have_current_path(%r{/t/#{topic.slug}/#{topic.id}})
    expect(nested_view).to have_no_nested_view

    topic.reload
    expect(topic.reload.nested_topic).to be_nil
  end
end
