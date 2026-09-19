# frozen_string_literal: true

describe "Composer - ProseMirror - Container" do
  include_context "with prosemirror editor"

  it "hides the Composer container's preview button" do
    page.visit "/new-topic"

    expect(composer).to be_opened
    expect(composer).to have_no_composer_preview_toggle

    composer.toggle_rich_editor

    expect(composer).to have_composer_preview_toggle
  end

  it "saves the user's rich editor preference and remembers it when reopening the composer" do
    open_composer
    expect(composer).to have_rich_editor_active
    composer.toggle_rich_editor
    expect(composer).to have_markdown_editor_active

    try_until_success(reason: "Relies on an Ember timer to update the user option") do
      expect(current_user.user_option.reload.composition_mode).to eq(
        UserOption.composition_mode_types[:markdown],
      )
    end

    visit("/")
    open_composer
    expect(composer).to have_markdown_editor_active
  end

  it "remembers the user's rich editor preference when starting a new PM" do
    current_user.user_option.update!(composition_mode: UserOption.composition_mode_types[:rich])
    page.visit("/u/#{current_user.username}/messages")
    find(".new-private-message").click
    expect(composer).to be_opened
    expect(composer).to have_rich_editor_active
  end

  it "handles uploads and disables the editor toggle while uploading" do
    open_composer

    file_path = file_from_fixtures("logo.png", "images").path
    cdp.with_slow_upload do
      attach_file("file-uploader", file_path, make_visible: true)
      expect(composer).to have_in_progress_uploads
      expect(composer.editor_toggle_switch).to be_disabled
    end

    expect(composer).to have_no_in_progress_uploads
    expect(rich).to have_css("img:not(.ProseMirror-separator)", count: 1)
  end
end
