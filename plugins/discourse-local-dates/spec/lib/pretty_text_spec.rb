require 'rails_helper'

describe PrettyText do
  it 'supports inserting date' do
    freeze_time
    cooked = PrettyText.cook <<~MD
      [date=2018-05-08 time=22:00 format=LLL timezones="Europe/Paris|America/Los_Angeles"]
    MD

    expect(cooked).to include('class="discourse-local-date"')
    expect(cooked).to include('data-date="2018-05-08"')
    expect(cooked).to include('data-format="LLL"')
    expect(cooked).to include('data-timezones="Europe/Paris|America/Los_Angeles"')
    expect(cooked).to include('May 8, 2018 3:00 PM (America: Los Angeles)')
    expect(cooked).to include('May 9, 2018 12:00 AM (Europe: Paris)')
  end

  it 'uses a simplified syntax in emails' do
    freeze_time
    cooked = PrettyText.cook <<~MD
      [date=2018-05-08 time=22:00 format=LLL timezones="Europe/Paris|America/Los_Angeles"]
    MD
    cooked_mail = <<~HTML
      <p><span class="discourse-local-date" data-date="2018-05-08" data-time="22:00" data-format="LLL" data-timezones="Europe/Paris|America/Los_Angeles" data-email-preview="May 9, 2018 12:00 AM (Europe: Paris)">May 9, 2018 12:00 AM (Europe: Paris)</span></p>
    HTML

    expect(PrettyText.format_for_email(cooked)).to match_html(cooked_mail)
  end

  it 'needs attributes to convert to a local date' do
    cooked = PrettyText.cook <<~MD
      [date]
    MD

    expect(cooked).to include("<p>[date]</p>")
  end
end
