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
        "span.discourse-local-date[data-date='2022-12-15'][data-time='14:19:00'][data-timezone='Asia/Singapore']",
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
        "span.discourse-local-date[data-date='2022-12-15'][data-time='14:19:00'][data-timezone='Asia/Singapore'][data-range='from']",
      )
      expect(rich).to have_css(
        "span.discourse-local-date[data-date='2022-12-16'][data-time='15:20:00'][data-timezone='Asia/Singapore'][data-range='to']",
      )
    end
  end

  describe "copy/paste within editor" do
    it "preserves all date and date-range attributes when copying and pasting" do
      cdp.allow_clipboard
      open_composer_and_toggle_rich_editor
      rich.click

      cdp.copy_paste <<~MARKDOWN
        [date=2022-12-15 time=14:19:00 timezone="Asia/Singapore" format="YYYY-MM-DD" recurring="1.weeks" timezones="Europe/Paris|Asia/Tokyo" countdown="true" displayedTimezone="Europe/London"]
        [date-range from=2022-12-15T14:19:00 to=2022-12-16T15:20:00 timezone="Asia/Singapore" format="YYYY-MM-DD" timezones="Europe/Paris" countdown="true" displayedTimezone="Europe/London"]
      MARKDOWN

      expect(rich).to have_css("span.discourse-local-date:not([data-range])", count: 1)
      expect(rich).to have_css("span.discourse-local-date-range", count: 1)

      # Select all and copy
      rich.send_keys([SystemHelpers::PLATFORM_KEY_MODIFIER, "a"])
      rich.send_keys([SystemHelpers::PLATFORM_KEY_MODIFIER, "c"])

      # Deselect, move to end, and paste
      rich.send_keys(:right)
      rich.send_keys(:enter)
      rich.send_keys([SystemHelpers::PLATFORM_KEY_MODIFIER, "v"])

      # Should now have double of everything with all attributes preserved
      expect(rich).to have_css("span.discourse-local-date:not([data-range])", count: 2)
      expect(rich).to have_css("span.discourse-local-date-range", count: 2)

      # Verify single date attributes are preserved
      expect(rich).to have_css(
        "span.discourse-local-date:not([data-range])" \
          "[data-date='2022-12-15'][data-time='14:19:00'][data-timezone='Asia/Singapore']" \
          "[data-format='YYYY-MM-DD'][data-recurring='1.weeks']" \
          "[data-timezones='Europe/Paris|Asia/Tokyo'][data-countdown='true']" \
          "[data-displayed-timezone='Europe/London']",
        count: 2,
      )

      # Verify date range attributes are preserved
      expect(rich).to have_css(
        "span.discourse-local-date[data-range='from']" \
          "[data-date='2022-12-15'][data-time='14:19:00'][data-timezone='Asia/Singapore']" \
          "[data-format='YYYY-MM-DD'][data-timezones='Europe/Paris']" \
          "[data-countdown='true'][data-displayed-timezone='Europe/London']",
        count: 2,
      )
      expect(rich).to have_css(
        "span.discourse-local-date[data-range='to']" \
          "[data-date='2022-12-16'][data-time='15:20:00'][data-timezone='Asia/Singapore']" \
          "[data-format='YYYY-MM-DD'][data-timezones='Europe/Paris']" \
          "[data-countdown='true'][data-displayed-timezone='Europe/London']",
        count: 2,
      )
    end
  end
end
