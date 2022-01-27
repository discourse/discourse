# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Local Dates" do
  before do
    freeze_time DateTime.parse('2018-11-10 12:00')
  end

  it "should work without timezone" do
    post = Fabricate(:post, raw: <<~TXT)
      [date=2018-05-08 time=22:00 format="L LTS" timezones="Europe/Paris|America/Los_Angeles"]
    TXT

    cooked = post.cooked

    expect(cooked).to include('class="discourse-local-date"')
    expect(cooked).to include('data-date="2018-05-08"')
    expect(cooked).to include('data-format="L LTS"')
    expect(cooked).not_to include('data-timezone=')

    expect(cooked).to include(
      'data-timezones="Europe/Paris|America/Los_Angeles"'
    )

    expect(cooked).to include('data-email-preview="2018-05-08T22:00:00Z UTC"')
    expect(cooked).to include('05/08/2018 10:00:00 PM')
  end

  it "should work with timezone" do
    post = Fabricate(:post, raw: <<~TXT)
      [date=2018-05-08 time=22:00 format="L LTS" timezone="Asia/Calcutta" timezones="Europe/Paris|America/Los_Angeles"]
    TXT

    cooked = post.cooked

    expect(cooked).to include('data-timezone="Asia/Calcutta"')
    expect(cooked).to include('05/08/2018 4:30:00 PM')
  end

  it 'requires the right attributes to convert to a local date' do
    post = Fabricate(:post, raw: <<~TXT)
      [date]
    TXT

    cooked = post.cooked

    expect(post.cooked).to include("<p>[date]</p>")
    expect(cooked).to_not include('data-date=')
  end

  it 'requires the right attributes to convert to a local date' do
    post = Fabricate(:post, raw: <<~TXT)
      [date]
    TXT

    cooked = post.cooked

    expect(post.cooked).to include("<p>[date]</p>")
    expect(cooked).to_not include('data-date=')
  end

  it 'it works with only a date and time' do
    raw = "[date=2018-11-01 time=12:00]"
    cooked = Fabricate(:post, raw: raw).cooked
    expect(cooked).to include('data-date="2018-11-01"')
    expect(cooked).to include('data-time="12:00"')
  end

  it 'doesn’t include format by default' do
    raw = "[date=2018-11-01 time=12:00]"
    cooked = Fabricate(:post, raw: raw).cooked
    expect(cooked).not_to include('data-format=')
  end

  it 'doesn’t include timezone by default' do
    raw = "[date=2018-11-01 time=12:00]"
    cooked = Fabricate(:post, raw: raw).cooked

    expect(cooked).not_to include("data-timezone=")
  end

  it 'supports countdowns' do
    raw = "[date=2018-11-01 time=12:00 countdown=true]"
    cooked = Fabricate(:post, raw: raw).cooked

    expect(cooked).to include("data-countdown=")
  end

  context 'ranges' do
    it 'generates ranges without time' do
      raw = "[date-range from=2022-01-06 to=2022-01-08]"
      cooked = Fabricate(:post, raw: raw).cooked

      expect(cooked).to include('data-date="2022-01-06')
      expect(cooked).to include('data-range="true"')
      expect(cooked).not_to include('data-time=')
    end

    it 'supports time and timezone' do
      raw = "[date-range from=2022-01-06T13:00 to=2022-01-08 timezone=Australia/Sydney]"
      cooked = Fabricate(:post, raw: raw).cooked

      expect(cooked).to include('data-date="2022-01-06')
      expect(cooked).to include('data-range="true"')
      expect(cooked).to include('data-time="13:00"')
      expect(cooked).to include('data-timezone="Australia/Sydney"')
    end

    it 'generates single date when range without end date' do
      raw = "[date-range from=2022-01-06T13:00]"
      cooked = Fabricate(:post, raw: raw).cooked

      expect(cooked).to include('data-date="2022-01-06')
      expect(cooked).to include('data-time="13:00"')
      expect(cooked).not_to include('data-range=')
    end
  end
end
