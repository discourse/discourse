# frozen_string_literal: true

RSpec.describe "Nested activity log" do
  fab!(:admin)
  fab!(:topic) { Fabricate(:topic, user: admin) }
  fab!(:op) { Fabricate(:post, topic: topic, user: admin, post_number: 1) }

  before do
    SiteSetting.nested_replies_enabled = true
    sign_in(admin)
  end

  it "opens the activity log modal and lists small actions" do
    topic.add_small_action(admin, "closed.enabled")

    page.visit("/n/#{topic.slug}/#{topic.id}")
    find(".nested-view__activity-link").click

    expect(page).to have_css(".nested-activity-log-modal")
    expect(page).to have_css(".nested-activity-log-modal__item", count: 2)
  end
end
