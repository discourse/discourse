# frozen_string_literal: true

RSpec.describe "User preferences tracking page" do
  with_select_controls(false)

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

  context "with the new select controls" do
    with_select_controls(true)

    let(:watched_tags) do
      PageObjects::Components::UiKit::DSelect.at(".tracking-controls__watched-tags .tag-chooser")
    end
    let(:tracked_tags) do
      PageObjects::Components::UiKit::DSelect.at(".tracking-controls__tracked-tags .tag-chooser")
    end
    let(:muted_tags) do
      PageObjects::Components::UiKit::DSelect.at(".tracking-controls__muted-tags .tag-chooser")
    end

    it "displays tag names instead of IDs with the new select controls" do
      TagUser.create!(user:, tag: tag1, notification_level: TagUser.notification_levels[:watching])
      TagUser.create!(user:, tag: tag2, notification_level: TagUser.notification_levels[:watching])
      TagUser.create!(user:, tag: tag3, notification_level: TagUser.notification_levels[:muted])
      TagUser.create!(user:, tag: tag4, notification_level: TagUser.notification_levels[:muted])

      visit "/u/#{user.username}/preferences/tracking"

      expect(watched_tags).to have_selected_names("javascript", "ruby")
      expect(muted_tags).to have_selected_names("python", "golang")
    end

    it "saves a tracked tag and hides tags chosen in another level with the new select controls" do
      TagUser.create!(user:, tag: tag1, notification_level: TagUser.notification_levels[:watching])

      visit "/u/#{user.username}/preferences/tracking"

      expect(watched_tags).to have_selected_names("javascript")

      tracked_tags.search("ruby")
      tracked_tags.select_name("ruby")
      tracked_tags.close

      expect(tracked_tags).to have_selected_names("ruby")

      muted_tags.search("a")
      expect(muted_tags).to have_option_name("python")
      expect(muted_tags).to have_no_option_name("javascript")
      expect(muted_tags).to have_no_option_name("ruby")
      muted_tags.close

      find(".save-changes").click
      expect(page).to have_css(".saved")

      expect(
        TagUser.where(user:, notification_level: TagUser.notification_levels[:tracking]).pluck(
          :tag_id,
        ),
      ).to contain_exactly(tag2.id)
    end
  end
end
