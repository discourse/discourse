# frozen_string_literal: true

describe "Composer - ProseMirror editor - Local Dates extension", type: :system do
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
    it "converts a single date bbcode to a local_date node" do
      cdp.allow_clipboard
      open_composer_and_toggle_rich_editor
      rich.click

      cdp.copy_paste <<~MARKDOWN
        [date=2022-12-15 time=14:19:00 timezone="Asia/Singapore"]
      MARKDOWN

      expect(rich).to have_css(
        "span.discourse-local-date[data-timezone='Asia/Singapore']",
        text: "2022-12-15 14:19:00",
      )
    end

    it "converts a date range bbcode to a local_date_range node" do
      cdp.allow_clipboard
      open_composer_and_toggle_rich_editor
      rich.click

      cdp.copy_paste <<~MARKDOWN
        [date-range from=2022-12-15T14:19:00 to=2022-12-16T15:20:00 timezone="Asia/Singapore"]
      MARKDOWN

      expect(rich).to have_css("span.discourse-local-date-range")
      expect(rich).to have_css(
        "span.discourse-local-date[data-timezone='Asia/Singapore'][data-range='from']",
        text: "2022-12-15 14:19:00",
      )
      expect(rich).to have_css(
        "span.discourse-local-date[data-timezone='Asia/Singapore'][data-range='to']",
        text: "2022-12-16 15:20:00",
      )
    end
  end
end
