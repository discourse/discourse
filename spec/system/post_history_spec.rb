# frozen_string_literal: true

describe "Post history with tag changes" do
  fab!(:admin)
  fab!(:tag1) { Fabricate(:tag, name: "alpha") }
  fab!(:tag2) { Fabricate(:tag, name: "beta") }
  fab!(:tag3) { Fabricate(:tag, name: "gamma") }
  fab!(:tag4) { Fabricate(:tag, name: "delta") }
  fab!(:topic) { Fabricate(:topic, user: admin, tags: [tag2, tag3]) }
  fab!(:post) { Fabricate(:post, topic:, user: admin, version: 2) }

  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:post_history_modal) { PageObjects::Modals::PostHistory.new }
  let(:mini_tag_chooser) { PageObjects::Components::SelectKit.new(".mini-tag-chooser") }

  before do
    SiteSetting.tagging_enabled = true
    SiteSetting.tag_topic_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
    SiteSetting.editing_grace_period = 0

    # a 'legacy' revision with string-array format for tags
    Fabricate(
      :post_revision,
      post: post,
      user: admin,
      number: 2,
      modifications: {
        "tags" => [[tag1.name], [tag2.name, tag3.name]],
      },
    )
  end

  it "shows tag changes from legacy format and new edits" do
    sign_in(admin)
    topic_page.visit_topic(topic)

    expect(page).to have_css(".post-info.edits")
    find(".post-info.edits").click
    expect(post_history_modal).to have_tag_changes
    expect(post_history_modal.deleted_tags).to contain_exactly(tag1.name)
    expect(post_history_modal.inserted_tags).to contain_exactly(tag2.name, tag3.name)

    post_history_modal.close

    # make a new edit: remove beta, add delta
    topic_page.click_topic_edit_title
    mini_tag_chooser.expand
    mini_tag_chooser.select_row_by_name(tag4.name)
    mini_tag_chooser.unselect_by_name(tag2.name)
    topic_page.click_topic_title_submit_edit

    expect(topic_page.topic_tags).to contain_exactly(tag3.name, tag4.name)
    expect(page).to have_css(".post-info.edits")
    find(".post-info.edits").click

    # verify new revision shows correctly (beta, gamma -> gamma, delta)
    expect(post_history_modal).to have_tag_changes
    expect(post_history_modal.deleted_tags).to contain_exactly(tag2.name)
    expect(post_history_modal.inserted_tags).to contain_exactly(tag4.name)

    # verify legacy format
    post_history_modal.click_previous_revision
    expect(post_history_modal.deleted_tags).to contain_exactly(tag1.name)
    expect(post_history_modal.inserted_tags).to contain_exactly(tag2.name, tag3.name)
  end
end

describe "Post history with a hidden revision" do
  include ThemeScreenshotMarker

  fab!(:admin)
  fab!(:post_owner, :user)
  fab!(:topic) { Fabricate(:topic, user: post_owner) }
  fab!(:post) { Fabricate(:post, topic: topic, user: post_owner, raw: "Initial public version") }

  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:post_history_modal) { PageObjects::Modals::PostHistory.new }

  before do
    SiteSetting.editing_grace_period = 0

    post.revise(post_owner, raw: "Second public version")
    post.revise(post_owner, raw: "Hidden secret version")
    post.revise(post_owner, raw: "Latest public version")
    post.revisions.find_by(number: 3).hide!
  end

  it "tells anonymous users why a diff can't be displayed instead of showing a blank space" do
    topic_page.visit_topic(topic)
    find(".post-info.edits").click

    expect(post_history_modal).to have_hidden_diff_notice
    screenshot_marker(label: "post-history-hidden-edit", only: :desktop)

    post_history_modal.click_previous_revision

    expect(post_history_modal).to have_hidden_diff_notice
  end

  it "still shows the diffs around the hidden revision to staff" do
    sign_in(admin)
    topic_page.visit_topic(topic)
    find(".post-info.edits").click

    expect(post_history_modal).to have_no_hidden_diff_notice
    expect(post_history_modal).to have_body_diff("Latest public version")
  end
end
