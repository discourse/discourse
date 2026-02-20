# frozen_string_literal: true

describe "Composer revisions", type: :system do
  fab!(:admin)
  fab!(:tag1) { Fabricate(:tag, name: "alpha") }
  fab!(:tag2) { Fabricate(:tag, name: "beta") }
  fab!(:topic) { Fabricate(:topic, user: admin, tags: [tag1]) }
  fab!(:post) { Fabricate(:post, topic:, user: admin) }

  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:post_history_modal) { PageObjects::Modals::PostHistory.new }
  let(:composer_tag_chooser) do
    PageObjects::Components::SelectKit.new("#reply-control .mini-tag-chooser")
  end

  before do
    SiteSetting.tagging_enabled = true
    SiteSetting.tag_topic_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
    SiteSetting.editing_grace_period = 0
    sign_in(admin)
  end

  it "saves the edit reason when editing only topic metadata from the composer" do
    topic_page.visit_topic(topic)
    topic_page.expand_post_actions(post)
    topic_page.click_post_action_button(post, :edit)

    expect(topic_page.composer).to be_opened

    composer_tag_chooser.expand
    composer_tag_chooser.select_row_by_name(tag2.name)

    find(".display-edit-reason").click
    fill_in "edit-reason", with: "correcting the tags"

    find("#reply-control .save-or-cancel .create").click
    expect(topic_page.composer).to be_closed

    expect(page).to have_css(".post-info.edits")
    find(".post-info.edits").click

    expect(post_history_modal).to have_edit_reason("correcting the tags")
  end
end
