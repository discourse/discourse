# frozen_string_literal: true

require "rails_helper"

describe DiscourseCalendar::GroupTimezones do
  before do
    Jobs.run_immediately!
    SiteSetting.calendar_enabled = true
  end

  let(:calendar_post) { create_post(raw: '[timezones group="admins"]\n[/timezones]') }

  it "converts the Markdown to HTML" do
    expect(calendar_post.cooked.rstrip).to match_html(<<~HTML.rstrip)
      <div class="group-timezones" data-group="admins" data-size="medium">
      <p>\\n</p>
      </div>
    HTML
  end

  it "creates correct custom fields" do
    calendar_post.reload
    expect(calendar_post.has_group_timezones?).to eq(true)
    expect(calendar_post.group_timezones).to eq("groups" => ["admins"])
  end
end
