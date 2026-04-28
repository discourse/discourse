# frozen_string_literal: true

describe "Composer - ProseMirror - Inline Diff" do
  include_context "with prosemirror editor"

  fab!(:topic) { Fabricate(:topic, user: current_user) }
  fab!(:post) do
    Fabricate(
      :post,
      topic:,
      user: current_user,
      raw: "First paragraph with some content\n\n## Original heading\n\nThird paragraph here",
    )
  end

  def toggle_inline_diff
    page.send_keys([SystemHelpers::PLATFORM_KEY_MODIFIER, :shift, "d"])
  end

  def edit_post_with(content)
    visit "/t/#{topic.slug}/#{topic.id}"
    find(".post-action-menu__edit").click
    expect(composer).to be_opened
    rich.send_keys([SystemHelpers::PLATFORM_KEY_MODIFIER, "a"])
    rich.send_keys(:delete)
    composer.type_content(content)
  end

  it "shows added and deleted text when editing content" do
    edit_post_with("First paragraph with different words")
    toggle_inline_diff

    expect(rich).to have_css(".diff-added", text: "different")
    expect(rich).to have_css(".diff-deleted")
  end

  it "shows deleted block nodes as widgets" do
    edit_post_with("First paragraph with some content")
    toggle_inline_diff

    expect(rich).to have_css(".diff-deleted-node", text: "Original heading")
  end

  it "can be toggled from the options menu" do
    edit_post_with("Changed via menu")

    composer.click_toolbar_options_item("toggle-diff")

    expect(rich).to have_css(".diff-added")
  end

  it "offers to switch to rich editor when in markdown mode" do
    current_user.user_option.update!(composition_mode: UserOption.composition_mode_types[:markdown])

    visit "/t/#{topic.slug}/#{topic.id}"
    find(".post-action-menu__edit").click
    expect(composer).to be_opened
    expect(composer).to have_no_rich_editor

    composer.click_toolbar_options_item("toggle-diff")

    expect(page).to have_css(".dialog-body")
    find(".dialog-footer .btn-primary").click

    expect(composer).to have_rich_editor
  end

  it "reverts a deleted block when clicking the revert button" do
    edit_post_with("First paragraph with some content")
    toggle_inline_diff

    expect(rich).to have_css(".diff-deleted-node", text: "Original heading")

    find(".ProseMirror .diff-deleted-node .diff-revert-button").click

    expect(rich).to have_css("h2", text: "Original heading")
    expect(rich).to have_no_css(".diff-deleted-node", text: "Original heading")
  end

  it "reverts via keyboard activation (Enter) on the focused button" do
    edit_post_with("First paragraph with some content")
    toggle_inline_diff

    expect(rich).to have_css(".diff-deleted-node", text: "Original heading")

    find(".ProseMirror .diff-deleted-node .diff-revert-button").send_keys(:enter)

    expect(rich).to have_css("h2", text: "Original heading")
    expect(rich).to have_no_css(".diff-deleted-node", text: "Original heading")
  end

  it "reverts the clicked revert button (not the first one) when there are several" do
    edit_post_with(
      "First paragraph edited content\n\n## Original heading\n\nThird paragraph edited too",
    )
    toggle_inline_diff

    page.all(".ProseMirror .diff-revert-button", minimum: 2).last.click

    expect(rich).to have_content("Third paragraph here")
    expect(rich).to have_no_content("edited too")

    expect(rich).to have_css(".diff-added")
    expect(rich).to have_css(".diff-deleted")
  end

  it "renders a structural split-block as a single added block, no orphan widgets" do
    # Put the cursor at end of "Third paragraph here" and press Enter, then
    # type into the new list item. This used to produce an empty pink strip
    # and a top-right orphan revert button because the split step has
    # non-zero PM size but no visible deleted content.
    edit_post_with(
      "First paragraph with some content\n\n## Original heading\n\nThird paragraph here",
    )
    toggle_inline_diff

    # Baseline: no changes yet, no widgets.
    expect(rich).to have_no_css(".diff-deleted")
    expect(rich).to have_no_css(".diff-deleted-node")
    expect(rich).to have_no_css(".diff-added")

    rich.send_keys(:end, :enter, "Fourth paragraph")

    # New content should appear as an added block with exactly one revert
    # button, not as a delete + add pair with a phantom widget.
    expect(rich).to have_css(".diff-added", text: "Fourth paragraph")
    expect(rich).to have_no_css(".diff-deleted")
    expect(rich).to have_no_css(".diff-deleted-node")
  end

  it "renders an inline text deletion inline, not as a block-level strike" do
    # Shortening a paragraph's text used to cascade through matchChildren:
    # the node's textContent changed enough to unmatch, and the whole block
    # reshuffled into a delete+add pair with a block-level strike bar.
    # With the changeset engine this should stay a clean inline deletion.
    edit_post_with("First paragraph\n\n## Original heading\n\nThird paragraph here")
    toggle_inline_diff

    expect(rich).to have_css(".diff-deleted", text: "with some content")
    expect(rich).to have_no_css(".diff-deleted-node", text: "with some content")
  end

  it "toggles off when pressing the shortcut again" do
    edit_post_with("Changed text")

    toggle_inline_diff
    expect(rich).to have_css(".diff-added")

    toggle_inline_diff
    expect(rich).to have_no_css(".diff-added")
    expect(rich).to have_no_css(".diff-deleted")
  end
end
