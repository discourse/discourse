require 'rails_helper'

RSpec.describe "Local Dates" do
  before do
    freeze_time
  end

  it "should work without timezone" do
    post = Fabricate(:post, raw: <<~SQL)
      [date=2018-05-08 time=22:00 format="L LTS" timezones="Europe/Paris|America/Los_Angeles"]
    SQL

    cooked = post.cooked

    expect(cooked).to include('class="discourse-local-date"')
    expect(cooked).to include('data-date="2018-05-08"')
    expect(cooked).to include('data-format="L LTS"')
    expect(cooked).not_to include('data-force-timezone=')

    expect(cooked).to include(
      'data-timezones="Europe/Paris|America/Los_Angeles"'
    )

    expect(cooked).to include('data-email-preview="05/09/2018 12:00:00 AM (Europe: Paris)"')
    expect(cooked).to include('05/08/2018 10:00:00 PM')
  end

  it "should work with timezone" do
    post = Fabricate(:post, raw: <<~SQL)
      [date=2018-05-08 time=22:00 format="L LTS" timezone="Asia/Calcutta" timezones="Europe/Paris|America/Los_Angeles"]
    SQL

    cooked = post.cooked

    expect(cooked).to include('data-force-timezone="Asia/Calcutta"')
    expect(cooked).to include('05/08/2018 4:30:00 PM')
  end

  it 'requires the right attributes to convert to a local date' do
    post = Fabricate(:post, raw: <<~SQL)
      [date]
    SQL

    cooked = post.cooked

    expect(post.cooked).to include("<p>[date]</p>")
    expect(cooked).to_not include('data-date=')
  end
end
