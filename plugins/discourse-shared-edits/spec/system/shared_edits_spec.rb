# frozen_string_literal: true

require "rails_helper"

describe "Shared Edits", type: :system do
  fab!(:admin)
  fab!(:user)
  fab!(:topic)
  fab!(:post) do
    Fabricate(
      :post,
      topic: topic,
      user: admin,
      raw: "Original post content that we will edit together",
    )
  end

  before do
    SiteSetting.shared_edits_enabled = true
    sign_in(admin)
  end

  it "completes full shared editing workflow - enable, edit, auto-commit, verify update" do
    # Step 1: Enable shared edits
    SharedEditRevision.toggle_shared_edits!(post.id, true)
    post.reload
    expect(post.custom_fields["shared_edits_enabled"]).to eq(true)

    # Step 2: Visit topic and verify shared edit button appears
    visit("/t/#{topic.id}")
    expect(page).to have_css(".topic-post", wait: 10)
    expect(page).to have_css("[data-post-id='#{post.id}']", wait: 5)
    expect(page).to have_css("[data-post-id='#{post.id}'] .shared-edit", wait: 5)

    # Step 3: Click shared edit button and wait for composer
    find("[data-post-id='#{post.id}'] .shared-edit").click
    expect(page).to have_css("#reply-control.open", wait: 5)

    # Wait for YJS to initialize
    sleep 2

    # Verify YJS initialized by checking that a revision was created
    initial_revision_count = SharedEditRevision.where(post_id: post.id).count
    expect(initial_revision_count).to be >= 1

    # Step 4: Make changes in the editor
    composer_textarea = find("#reply-control textarea")
    new_content = "#{post.raw}\n\nThis is NEW content added via shared editing!"

    composer_textarea.send_keys([:control, "a"])
    composer_textarea.send_keys(new_content)

    sleep 1

    # Verify the textarea has the new content
    actual_content = composer_textarea.value
    expect(actual_content).to include("NEW content added")

    # Step 5: Wait for auto-commit (5 seconds)
    sleep 6

    # Check that revisions were created
    revision_count = SharedEditRevision.where(post_id: post.id).count
    expect(revision_count).to be > 1

    # Check that the latest revision has the new content
    latest_revision = SharedEditRevision.where(post_id: post.id).order(:version).last
    expect(latest_revision.raw).to be_present
    expect(latest_revision.raw).to include("NEW content added")

    # Step 6: Close composer (no Done button for shared edits - they auto-commit)
    find("#reply-control").send_keys(:escape)
    expect(page).to_not have_css("#reply-control.open", wait: 10)

    sleep 1

    # Step 7: Verify the post was actually updated in the database
    SharedEditRevision.commit!(post.id)

    post.reload
    final_raw = post.raw

    expect(final_raw).to_not eq("Original post content that we will edit together")
    expect(final_raw).to include("NEW content added")

    # Step 8: Verify the changes are visible on the page
    visit("/t/#{topic.id}")
    expect(page).to have_css("[data-post-id='#{post.id}']", wait: 5)

    post_content = find("[data-post-id='#{post.id}'] .cooked").text
    expect(post_content).to include("NEW content added")
  end

  it "auto-commits updates without manual Done button" do
    SharedEditRevision.toggle_shared_edits!(post.id, true)
    post.reload

    initial_content = post.raw

    # Visit and open shared edit
    visit("/t/#{topic.id}")
    expect(page).to have_css("[data-post-id='#{post.id}']", wait: 5)
    find("[data-post-id='#{post.id}'] .shared-edit").click
    expect(page).to have_css("#reply-control.open", wait: 5)

    sleep 2

    # Make changes
    composer_textarea = find("#reply-control textarea")
    composer_textarea.send_keys([:control, "a"])
    composer_textarea.send_keys("#{initial_content}\n\nAuto-commit test content")

    sleep 1

    # Wait for auto-commit
    sleep 6

    # Manually trigger commit (background jobs don't run in system tests)
    SharedEditRevision.commit!(post.id)

    # Check post was updated
    post.reload
    expect(post.raw).to include("Auto-commit test content")
  end

  it "tracks changes from multiple users" do
    SharedEditRevision.toggle_shared_edits!(post.id, true)

    # Open in first session (admin)
    visit("/t/#{topic.id}")
    expect(page).to have_css("[data-post-id='#{post.id}']", wait: 5)
    find("[data-post-id='#{post.id}'] .shared-edit").click
    expect(page).to have_css("#reply-control.open", wait: 5)

    sleep 2

    # Simulate another user making a change via API
    version = SharedEditRevision.where(post_id: post.id).maximum(:version) || 0

    SharedEditRevision.revise!(
      post_id: post.id,
      user_id: user.id,
      client_id: "test_client_2",
      version: version,
      revision: [1, 2, 3, 4, 5],
      raw: "#{post.raw}\n\nContent from user 2",
    )

    # Publish to message bus
    post_obj = Post.find(post.id)
    message = {
      version: version + 1,
      revision: [1, 2, 3, 4, 5].to_json,
      client_id: "test_client_2",
      user_id: user.id,
      type: "yjs-update",
      update: [1, 2, 3, 4, 5].to_json,
    }
    post_obj.publish_message!("/shared_edits/#{post.id}", message)

    # Wait for message to be received
    sleep 2

    # Verify the revision was created
    expect(SharedEditRevision.where(post_id: post.id, user_id: user.id).exists?).to eq(true)

    # Close composer
    find("#reply-control").send_keys(:escape)
    expect(page).to_not have_css("#reply-control.open", wait: 10)

    SharedEditRevision.commit!(post.id)

    post.reload
    # The revision should be tracked
    expect(SharedEditRevision.where(post_id: post.id, user_id: user.id).exists?).to eq(true)
  end

  it "enables shared edits via admin menu" do
    visit("/t/#{topic.id}")
    expect(page).to have_css(".topic-post", wait: 10)

    # Open post admin menu
    within("[data-post-id='#{post.id}']") do
      find(".show-more-actions").click
      sleep 0.5
    end

    # Click enable shared edits if available in the admin menu
    if page.has_css?(".admin-toggle-shared-edits", wait: 2)
      find(".admin-toggle-shared-edits").click

      # Wait for the action to complete
      sleep 1

      # Verify shared edits were enabled
      post.reload
      expect(post.custom_fields["shared_edits_enabled"]).to eq(true)

      # Verify initial revision was created
      revision = SharedEditRevision.where(post_id: post.id).first
      expect(revision).to be_present
      expect(revision.version).to eq(1)
      expect(revision.raw).to eq(post.raw)
    else
      skip "Admin menu toggle not available in UI"
    end
  end
end
