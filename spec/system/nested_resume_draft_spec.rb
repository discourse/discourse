# frozen_string_literal: true

RSpec.describe "Nested view resuming a draft from the user activity page" do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:topic) { Fabricate(:topic, user: user) }
  fab!(:op) { Fabricate(:post, topic: topic, user: user, post_number: 1) }

  let(:drafts_page) { PageObjects::Pages::UserActivityDrafts.new }
  let(:nested_view) { PageObjects::Pages::NestedView.new }
  let(:composer) { PageObjects::Components::Composer.new }

  before do
    SiteSetting.nested_replies_enabled = true
    Fabricate(:nested_topic, topic: topic)
    Draft.set(
      user,
      "#{Draft::EXISTING_TOPIC}#{topic.id}",
      0,
      { reply: "Resumed nested draft body", action: "reply" }.to_json,
    )
    sign_in(user)
  end

  it "opens the composer with the draft body when resuming a nested topic draft" do
    drafts_page.visit(user)
    page.find(".resume-draft").click

    expect(page).to have_current_path(%r{/n/})
    expect(nested_view).to have_nested_view
    expect(composer).to be_opened
    expect(composer).to have_content("Resumed nested draft body")
  end
end
