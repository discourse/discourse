# frozen_string_literal: true

RSpec.shared_context "with prosemirror editor" do
  fab!(:current_user) do
    Fabricate(
      :user,
      refresh_auto_groups: true,
      composition_mode: UserOption.composition_mode_types[:rich],
    )
  end

  let(:cdp) { PageObjects::CDP.new }
  let(:composer) { PageObjects::Components::Composer.new }
  let(:rich) { composer.rich_editor }

  before { sign_in(current_user) }

  def open_composer
    browser_page.goto("/new-topic").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(composer).to be_opened
    composer.focus
  end

  def paste_and_click_image
    # This helper can only be used reliably to paste a single image when no other images are present.
    rich.wait_for(state: "visible")
    expect(rich.locator(".composer-image-node img").filter(visible: true)).to have_count(0)

    cdp.allow_clipboard
    cdp.copy_test_image
    cdp.paste

    expect(composer).to have_no_in_progress_uploads
    image = rich.locator(".composer-image-node img").filter(visible: true)
    expect(image).to have_count(1)
    expect(rich.locator(".composer-image-node img[src='/images/transparent.png']")).to have_count(0)
    expect(image).not_to have_attribute("data-placeholder")

    image.click
    expect(rich.locator(".composer-image-node .fk-d-menu")).to have_count(2)
  end
end

RSpec.shared_context "with native prosemirror editor" do
  include_context "with prosemirror editor"

  let(:composer) { PageObjects::Native::Composer.new(browser_page) }

  def open_composer
    composer.visit
    expect(composer.opened_composer).to be_visible
    composer.editor.click
  end
end
