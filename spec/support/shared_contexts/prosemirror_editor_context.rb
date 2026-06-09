# frozen_string_literal: true

RSpec.shared_context "with prosemirror editor" do
  fab!(:current_user) do
    Fabricate(
      :user,
      refresh_auto_groups: true,
      composition_mode: UserOption.composition_mode_types[:rich],
    )
  end

  # NOTE: The hashtag/tag autocomplete fixtures (`tag`, `category_with_emoji`,
  # `category_with_icon`, `category_without_icon`) used to live here and were
  # eagerly fabricated for every example in all 15 prosemirror spec files, but
  # only the autocomplete and keymap specs reference them. Fabricating each of
  # those categories also creates a `user` association, so ~13 of the files paid
  # for 3 categories + 3 users + 1 tag per example with nothing using them. They
  # now live in the two specs that actually need them.

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

    expect(composer).to have_no_in_progress_uploads
    expect(rich).to have_css(".composer-image-node img", count: 1)
    expect(rich).to have_no_css(".composer-image-node img[src='/images/transparent.png']")
    expect(rich).to have_no_css("img[data-placeholder='true']")

    rich.find(".composer-image-node img").click

    expect(rich).to have_css(".composer-image-node .fk-d-menu", count: 2)
  end
end
