require 'rails_helper'

describe PrettyText do
  it 'uses a simplified syntax in emails' do
    freeze_time
    cooked = PrettyText.cook <<~MD
      [date=2018-05-08 time=22:00 format=LLL timezones="Europe/Paris|America/Los_Angeles"]
    MD
    cooked_mail = <<~HTML
      <p><span class="discourse-local-date" data-date="2018-05-08" data-format="LLL" data-timezones="Europe/Paris|America/Los_Angeles" data-time="22:00" data-email-preview="May 9, 2018 12:00 AM (Europe: Paris)">May 9, 2018 12:00 AM (Europe: Paris)</span></p>
    HTML

    expect(PrettyText.format_for_email(cooked)).to match_html(cooked_mail)

    cooked = PrettyText.cook <<~MD
      [date=2018-05-08 format=LLL timezone="Europe/Berlin" timezones="Europe/Paris|America/Los_Angeles"]
    MD
    cooked_mail = <<~HTML
      <p><span class="discourse-local-date" data-date="2018-05-08" data-format="LLL" data-timezones="Europe/Paris|America/Los_Angeles" data-timezone="Europe/Berlin" data-email-preview="May 8, 2018 12:00 AM (Europe: Paris)">May 8, 2018 12:00 AM (Europe: Paris)</span></p>
    HTML

    expect(PrettyText.format_for_email(cooked)).to match_html(cooked_mail)
  end
end
