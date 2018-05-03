require 'rails_helper'

describe PrettyText do
  it 'supports inserting date' do
    freeze_time
    cooked = PrettyText.cook <<~MD
      [discourse-cronos time=22:00;date=2018-05-08;format=LLL;timezones=Europe/Paris|America/Los_Angeles;][/discourse-cronos]
    MD

    expect(cooked).to include('class="discourse-cronos"')
    expect(cooked).to include('data-date="2018-05-08"')
    expect(cooked).to include('data-format="LLL"')
    expect(cooked).to include('data-timezones="Europe/Paris|America/Los_Angeles"')
    expect(cooked).to include('May 8, 2018 3:00 PM (America: Los Angeles)')
    expect(cooked).to include('May 9, 2018 12:00 AM (Europe: Paris)')
  end
end
