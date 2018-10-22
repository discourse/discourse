require 'rails_helper'

describe Post do

  before do
    SiteSetting.queue_jobs = false
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
  end

end
