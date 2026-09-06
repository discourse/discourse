# frozen_string_literal: true

describe "Composer - ProseMirror editor - Local Dates extension" do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  let(:cdp) { PageObjects::CDP.new }
  let(:composer) { PageObjects::Components::Composer.new }
  let(:rich) { composer.rich_editor }
  let(:insert_datetime_modal) { PageObjects::Modals::InsertDateTime.new }

  before { sign_in(user) }

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

  describe "editing a date" do
    def paste_and_edit(markdown)
      cdp.allow_clipboard
      open_composer_and_toggle_rich_editor
      rich.click

      cdp.copy_paste(markdown)

      rich.find(".composer-local-date__edit-button").click
      expect(insert_datetime_modal).to be_open
    end

    it "opens the modal seeded with the date and replaces the node on save" do
      paste_and_edit(<<~MARKDOWN)
        [date=2022-12-15 time=14:19:00 timezone="Asia/Singapore"]
      MARKDOWN

      insert_datetime_modal.calendar_date_time_picker.fill_time("11:45")
      insert_datetime_modal.click_primary_button

      expect(rich).to have_css(
        "span.discourse-local-date[data-date='2022-12-15'][data-time='11:45:00']" \
          "[data-timezone='Asia/Singapore']",
      )

      composer.toggle_rich_editor

      expect(composer).to have_value("[date=2022-12-15 time=11:45:00 timezone=Asia/Singapore]")
    end

    it "keeps attributes the form has no field for" do
      paste_and_edit(<<~MARKDOWN)
        [date=2022-12-15 time=14:19:00 timezone="Asia/Singapore" countdown=true displayedTimezone=Europe/London]
      MARKDOWN

      insert_datetime_modal.calendar_date_time_picker.fill_time("11:45")
      insert_datetime_modal.click_primary_button

      expect(rich).to have_css(
        "span.discourse-local-date[data-time='11:45:00'][data-countdown='true']" \
          "[data-displayed-timezone='Europe/London']",
      )
    end

    it "edits the end of a date range" do
      paste_and_edit(<<~MARKDOWN)
        [date-range from=2022-12-15T14:19:00 to=2022-12-16T15:20:00 timezone="Asia/Singapore"]
      MARKDOWN

      insert_datetime_modal.select_to
      insert_datetime_modal.calendar_date_time_picker.fill_time("16:30")
      insert_datetime_modal.click_primary_button

      expect(rich).to have_css(
        "span.discourse-local-date[data-range='to'][data-date='2022-12-16']" \
          "[data-time='16:30:00']",
      )
    end

    it "shows the timezone preview when the date itself is clicked" do
      cdp.allow_clipboard
      open_composer_and_toggle_rich_editor
      rich.click

      cdp.copy_paste(<<~MARKDOWN)
        [date=2022-12-15 time=14:19:00 timezone="Asia/Singapore"]
      MARKDOWN

      rich.find("span.discourse-local-date").click

      expect(page).to have_css("[data-content] .locale-dates-previews")
    end

    it "reaches the edit button with the keyboard" do
      cdp.allow_clipboard
      open_composer_and_toggle_rich_editor
      rich.click

      cdp.copy_paste(<<~MARKDOWN)
        Meeting is [date=2022-12-15 time=14:19:00 timezone="Asia/Singapore"] ok
      MARKDOWN

      # arrow onto the chip, which selects it as a node
      4.times { rich.send_keys(:left) }
      expect(rich).to have_css(".composer-local-date.ProseMirror-selectednode")

      rich.send_keys(:tab)
      expect(rich).to have_css(".composer-local-date__edit-button:focus")

      page.send_keys(:enter)
      expect(insert_datetime_modal).to be_open
    end

    it "tabs focus back to the editor from the edit button" do
      cdp.allow_clipboard
      open_composer_and_toggle_rich_editor
      rich.click

      cdp.copy_paste(<<~MARKDOWN)
        Meeting is [date=2022-12-15 time=14:19:00 timezone="Asia/Singapore"] ok
      MARKDOWN

      4.times { rich.send_keys(:left) }
      rich.send_keys(:tab)
      expect(rich).to have_css(".composer-local-date__edit-button:focus")

      page.send_keys(:tab)
      expect(page).to have_css(".ProseMirror:focus")
    end
  end
end
