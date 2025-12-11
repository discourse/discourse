# frozen_string_literal: true

RSpec.shared_context "with prosemirror editor" do
  fab!(:current_user) do
    Fabricate(
      :user,
      refresh_auto_groups: true,
      composition_mode: UserOption.composition_mode_types[:rich],
    )
  end

  fab!(:tag)
  fab!(:category_with_emoji) do
    Fabricate(:category, slug: "cat", emoji: "cat", style_type: "emoji")
  end
  fab!(:category_with_icon) { Fabricate(:category, icon: "bell", style_type: "icon") }
  fab!(:category_without_icon, :category)

  let(:cdp) { PageObjects::CDP.new }
  let(:composer) { PageObjects::Components::Composer.new }
  let(:rich) { composer.rich_editor }

  before { sign_in(current_user) }

  def open_composer
    page.visit "/new-topic"
    expect(composer).to be_opened
    composer.focus
  end

  def paste_and_click_image
    # This helper can only be used reliably to paste a single image when no other images are present.
    expect(rich).to have_no_css(".composer-image-node img")

    cdp.allow_clipboard
    cdp.copy_test_image
    cdp.paste

    expect(rich).to have_css(".composer-image-node img", count: 1)
    expect(rich).to have_no_css(".composer-image-node img[src='/images/transparent.png']")
    expect(rich).to have_no_css(".composer-image-node img[data-placeholder='true']")

    rich.find(".composer-image-node img").click

    expect(rich).to have_css(".composer-image-node .fk-d-menu", count: 2)
  end
end
