# frozen_string_literal: true

require 'rails_helper'

describe Post do

  before do
    Jobs.run_immediately!
  end

  describe '#local_dates' do
    it "should have correct custom fields" do
      post = Fabricate(:post, raw: <<~SQL)
        [date=2018-09-17 time=01:39:00 format="LLL" timezone="Europe/Paris" timezones="Europe/Paris|America/Los_Angeles"]
      SQL
      CookedPostProcessor.new(post).post_process

      expect(post.local_dates.count).to eq(1)
      expect(post.local_dates[0]["date"]).to eq("2018-09-17")
      expect(post.local_dates[0]["time"]).to eq("01:39:00")
      expect(post.local_dates[0]["timezone"]).to eq("Europe/Paris")

      post.raw = "Text removed"
      post.save
      CookedPostProcessor.new(post).post_process

      expect(post.local_dates).to eq([])
    end

    it "should not contain dates from quotes" do
      post = Fabricate(:post, raw: <<~SQL)
        [quote]
          [date=2018-09-17 time=01:39:00 format="LLL" timezone="Europe/Paris" timezones="Europe/Paris|America/Los_Angeles"]
        [/quote]
      SQL
      CookedPostProcessor.new(post).post_process

      expect(post.local_dates.count).to eq(0)
    end

    it "should not contain dates from examples" do
      Oneboxer.stubs(:cached_onebox).with('https://example.com').returns(<<-HTML)
        <aside class="onebox githubcommit">
          <span class="discourse-local-date" data-format="ll" data-date="2020-01-20" data-time="15:06:58" data-timezone="UTC">03:06PM - 20 Jan 20 UTC</span>
        </aside>
      HTML
      post = Fabricate(:post, raw: "https://example.com")
      CookedPostProcessor.new(post).post_process

      expect(post.local_dates.count).to eq(0)
    end
  end

end
