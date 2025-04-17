# frozen_string_literal: true

describe "Composer - ProseMirror editor - Footnote extension", type: :system do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  let(:cdp) { PageObjects::CDP.new }
  let(:composer) { PageObjects::Components::Composer.new }
  let(:rich) { composer.rich_editor }

  before do
    sign_in(user)
    SiteSetting.rich_editor = true
  end

  def open_composer_and_toggle_rich_editor
    page.visit "/new-topic"
    expect(composer).to be_opened
    composer.toggle_rich_editor
  end

  describe "pasting content" do
    it "converts inline footnotes" do
      cdp.allow_clipboard
      open_composer_and_toggle_rich_editor
      rich.click

      cdp.copy_paste <<~MARKDOWN
        What is this? ^[multiple inline] ^[footnotes]
      MARKDOWN

      expect(rich).to have_css("div.footnote", count: 2)

      composer.toggle_rich_editor

      expect(composer).to have_value("What is this? ^[multiple inline] ^[footnotes]")
    end

    it "converts block footnotes" do
      cdp.allow_clipboard
      open_composer_and_toggle_rich_editor
      rich.click

      cdp.copy_paste <<~MARKDOWN
        Hey [^1] [^2]
        [^1]: This is inline
        [^2]: This

            > not so much
      MARKDOWN

      expect(rich).to have_css("div.footnote", count: 2)

      composer.toggle_rich_editor

      expect(composer).to have_value(
        "Hey ^[This is inline] [^1]\n\n[^1]: This\n\n    > not so much",
      )
    end

    it "converts inline footnotes when typing" do
      open_composer_and_toggle_rich_editor
      rich.click

      rich.send_keys("What is this? ^[multiple inline] ^[footnotes]")

      expect(rich).to have_css("div.footnote", count: 2)

      composer.toggle_rich_editor

      expect(composer).to have_value("What is this? ^[multiple inline] ^[footnotes]")
    end
  end
end
