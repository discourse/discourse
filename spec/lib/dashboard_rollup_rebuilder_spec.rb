# frozen_string_literal: true

RSpec.describe DashboardRollupRebuilder do
  subject(:rebuilder) { described_class.new(io: StringIO.new) }

  describe "#rebuild!" do
    it "rebuilds country and referrer rollups from the events they summarise" do
      Fabricate(:browser_pageview_event, country_code: "US", normalized_referrer: "google.com")
      BrowserPageviewCountryDailyRollup.aggregate(start_date: 1.day.ago, end_date: Time.zone.today)
      BrowserPageviewReferrerDailyRollup.aggregate(start_date: 1.day.ago, end_date: Time.zone.today)
      BrowserPageviewCountryDailyRollup.delete_all
      BrowserPageviewReferrerDailyRollup.delete_all

      rebuilder.rebuild!

      expect(BrowserPageviewCountryDailyRollup.sum(:count)).to eq(1)
      expect(BrowserPageviewReferrerDailyRollup.sum(:count)).to eq(1)
    end

    it "populates crawler counts on rollups that were built without them" do
      SiteSetting.improved_crawler_detection = true
      Fabricate(:browser_pageview_event, country_code: "US", score: 90)
      BrowserPageviewCountryDailyRollup.aggregate(start_date: 1.day.ago, end_date: Time.zone.today)
      BrowserPageviewCountryDailyRollup.update_all(likely_crawler_count: 0)

      rebuilder.rebuild!("browser_pageview_country")

      expect(BrowserPageviewCountryDailyRollup.sum(:likely_crawler_count)).to eq(1)
    end

    it "rebuilds only the named rollup" do
      Fabricate(:browser_pageview_event, country_code: "US")

      rebuilder.rebuild!("browser_pageview_country")

      expect(BrowserPageviewCountryDailyRollup.count).to eq(1)
      expect(BrowserPageviewReferrerDailyRollup.count).to eq(0)
    end

    it "leaves browser pageview rollups empty when no events exist" do
      expect { rebuilder.rebuild!("browser_pageview_country") }.not_to change {
        BrowserPageviewCountryDailyRollup.count
      }
    end

    it "leaves user visit rollups empty when nobody has visited" do
      UserVisit.delete_all

      expect { rebuilder.rebuild!("user_visit") }.not_to change { UserVisitDailyRollup.count }
    end
  end

  describe ".known?" do
    it "recognises every rollup it can rebuild and rejects anything else" do
      expect(described_class.names).to all(satisfy { |name| described_class.known?(name) })
      expect(described_class.known?("nope")).to eq(false)
    end
  end
end
