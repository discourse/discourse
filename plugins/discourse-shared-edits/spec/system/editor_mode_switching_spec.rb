# frozen_string_literal: true

require "rails_helper"

describe "Editor Mode Restrictions", type: :system do
  fab!(:admin)
  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic: topic, user: admin, raw: "Original content") }

  before do
    SiteSetting.shared_edits_enabled = true
    SiteSetting.rich_editor = true
    sign_in(admin)
  end

  it "forces rich mode and hides mode switcher for shared edits" do
    # Enable shared edits on the post
    SharedEditRevision.toggle_shared_edits!(post.id, true)
    post.reload

    # Visit topic
    visit("/t/#{topic.slug}/#{topic.id}")
    expect(page).to have_css(".topic-post", wait: 5)

    # Verify post is present and has shared edit button
    expect(page).to have_css("[data-post-id='#{post.id}']", wait: 5)
    expect(page).to have_css("[data-post-id='#{post.id}'] .shared-edit")

    # Click the shared edit button
    find("[data-post-id='#{post.id}'] .shared-edit").click
    expect(page).to have_css("#reply-control.open", wait: 5)

    # Verify we have the ProseMirror editor (rich mode is forced)
    expect(page).to have_css(".ProseMirror", wait: 5)
    expect(page).not_to have_css("textarea.d-editor-input")

    # Verify mode switcher is hidden for shared edits
    mode_switcher_buttons =
      page
        .all(".d-editor-container button, .composer-fields button")
        .select do |btn|
          btn[:title]&.downcase&.include?("markdown") || btn[:title]&.downcase&.include?("rich") ||
            btn[:class]&.include?("toggle")
        end

    expect(mode_switcher_buttons).to be_empty, "Mode switcher should be hidden for shared edits"

    # Type and verify editing works
    prosemirror = find(".ProseMirror")
    prosemirror.click
    prosemirror.send_keys(" Test content")

    sleep 1

    expect(prosemirror.text).to include("Test content")
    expect(SharedEditRevision.where(post_id: post.id, user_id: admin.id).count).to be >= 1
  end

  it "forces rich mode even if user prefers markdown" do
    # User prefers markdown mode
    admin.user_option.update!(composition_mode: UserOption.composition_mode_types[:markdown])

    SharedEditRevision.toggle_shared_edits!(post.id, true)
    post.reload

    # Open shared edit
    visit("/t/#{topic.slug}/#{topic.id}")
    find("[data-post-id='#{post.id}'] .shared-edit").click

    # Should still get ProseMirror (rich mode is forced)
    expect(page).to have_css(".ProseMirror", wait: 5)
    expect(page).not_to have_css("textarea.d-editor-input")

    # Close composer
    find("#reply-control").send_keys(:escape)
    sleep 0.5

    # User preference should not change after shared edit
    admin.user_option.reload
    expect(admin.user_option.composition_mode).to eq(UserOption.composition_mode_types[:markdown])
  end
end
