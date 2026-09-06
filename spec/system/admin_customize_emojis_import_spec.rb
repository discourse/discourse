# frozen_string_literal: true

describe "Admin Emoji Bulk Import" do
  fab!(:current_user, :admin)

  let(:emojis_page) { PageObjects::Pages::AdminEmojis.new }
  let(:dialog) { PageObjects::Components::Dialog.new }

  let(:sample_zip) { Rails.public_path.join("emoji-import-sample.zip") }

  before { sign_in(current_user) }

  it "imports emojis from the sample ZIP and shows them in the list" do
    emojis_page.visit_import_page

    emojis_page.upload_zip(sample_zip)

    expect(emojis_page).to have_import_preview

    emojis_page.confirm_import

    expect(page).to have_current_path("/admin/config/emoji")
    expect(emojis_page).to have_emoji_listed("discourse")
  end

  it "can re-import without error when emoji already exists (conflict resolution)" do
    emojis_page.visit_import_page
    emojis_page.upload_zip(sample_zip)
    emojis_page.confirm_import

    emojis_page.visit_import_page
    emojis_page.upload_zip(sample_zip)

    expect(emojis_page).to have_import_preview

    emojis_page.confirm_import

    expect(page).to have_current_path("/admin/config/emoji")
    expect(emojis_page).to have_emoji_listed("discourse")
  end
end
