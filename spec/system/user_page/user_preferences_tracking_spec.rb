# frozen_string_literal: true

RSpec.describe "User preferences tracking page", type: :system do
  fab!(:user)
  fab!(:tag1) { Fabricate(:tag, name: "javascript") }
  fab!(:tag2) { Fabricate(:tag, name: "ruby") }
  fab!(:tag3) { Fabricate(:tag, name: "python") }
  fab!(:tag4) { Fabricate(:tag, name: "golang") }

  let(:watched_tags) do
    PageObjects::Components::SelectKit.new(".tracking-controls__watched-tags .tag-chooser")
  end
  let(:muted_tags) do
    PageObjects::Components::SelectKit.new(".tracking-controls__muted-tags .tag-chooser")
  end

  before do
    SiteSetting.tagging_enabled = true
    sign_in(user)
  end

  it "displays tag names instead of IDs" do
    TagUser.create!(user:, tag: tag1, notification_level: TagUser.notification_levels[:watching])
    TagUser.create!(user:, tag: tag2, notification_level: TagUser.notification_levels[:watching])
    TagUser.create!(user:, tag: tag3, notification_level: TagUser.notification_levels[:muted])
    TagUser.create!(user:, tag: tag4, notification_level: TagUser.notification_levels[:muted])

    visit "/u/#{user.username}/preferences/tracking"

    expect(watched_tags).to have_selected_names("javascript", "ruby")
    expect(muted_tags).to have_selected_names("python", "golang")
  end
end
