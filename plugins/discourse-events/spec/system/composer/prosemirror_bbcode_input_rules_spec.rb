# frozen_string_literal: true

describe "Composer - ProseMirror - Events bbcode input rules" do
  include_context "with prosemirror editor"

  before { SiteSetting.discourse_events_enabled = true }

  it "turns a typed calendar tag into a calendar" do
    open_composer
    composer.type_content("[calendar]")

    expect(rich).to have_css(".composer-calendar-preview")
    composer.toggle_rich_editor
    expect(composer.composer_input.value).to include("[calendar]\n[/calendar]")
  end

  it "keeps the attributes typed with the calendar tag" do
    open_composer
    composer.type_content("[calendar type=static]")

    expect(rich).to have_css(".composer-calendar-preview__body[data-calendar-type='static']")
  end

  it "leaves a tag that only shares the calendar prefix alone" do
    open_composer
    composer.type_content("[calendars]")

    expect(rich).to have_no_css(".composer-calendar-preview")
    expect(rich).to have_text("[calendars]")
  end

  it "turns a typed timezones tag with a group into group timezones" do
    open_composer
    composer.type_content("[timezones group=admins]")

    expect(rich).to have_css(".composer-group-timezones-preview")
    composer.toggle_rich_editor
    expect(composer.composer_input.value).to include("[timezones group=admins]\n[/timezones]")
  end

  it "leaves a group-less timezones tag alone" do
    open_composer
    composer.type_content("[timezones]")

    expect(rich).to have_no_css(".composer-group-timezones-preview")
    expect(rich).to have_text("[timezones]")
  end
end
