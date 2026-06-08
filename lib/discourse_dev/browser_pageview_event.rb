# frozen_string_literal: true

require "discourse_dev"

module DiscourseDev
  class BrowserPageviewEvent
    DEFAULT_COUNT = 1500
    DEFAULT_RANGE = 3.months

    COUNTRY_WEIGHTS = {
      "US" => 40,
      "GB" => 15,
      "DE" => 10,
      "FR" => 8,
      "CA" => 8,
      "AU" => 5,
      "BR" => 5,
      "JP" => 4,
      "IN" => 3,
      "CN" => 2,
      nil => 5,
    }.freeze

    REFERRERS = [
      "news.ycombinator.com/item?id=42",
      "news.ycombinator.com/item?id=99",
      "news.ycombinator.com",
      "reddit.com/r/discourse",
      "reddit.com/r/programming",
      "twitter.com/discourse",
      "google.com",
      "github.com/discourse/discourse",
      "facebook.com",
      "m.facebook.com",
      nil,
      nil,
      nil,
    ].freeze

    def initialize(count: DEFAULT_COUNT)
      @count = count
    end

    def populate!
      unless Discourse.allow_dev_populate?
        raise 'To run this rake task in a production site, set the value of `ALLOW_DEV_POPULATE` environment variable to "1"'
      end

      SiteSetting.persist_browser_pageview_events = true

      rows = build_rows
      ::BrowserPageviewEvent.insert_all(rows)
      mirror_to_application_requests(rows)

      puts "Enabled persist_browser_pageview_events and inserted #{rows.size} events."
      rows.size
    end

    def self.populate!(count: nil)
      new(count: count || DEFAULT_COUNT).populate!
    end

    private

    attr_reader :count

    def build_rows
      country_pool = COUNTRY_WEIGHTS.flat_map { |code, weight| [code] * weight }
      user_ids = ::User.real.limit(20).pluck(:id)
      user_id_pool = user_ids + ([nil] * [user_ids.size / 4, 1].max)

      Array.new(count) do
        normalized = REFERRERS.sample
        {
          url: "https://forum.example.com/t/sample-topic/#{rand(1000)}",
          ip_address: "192.0.2.#{rand(1..254)}",
          user_agent: "Mozilla/5.0 (X11; Linux x86_64) Chrome/123",
          session_id: SecureRandom.hex(16),
          country_code: country_pool.sample,
          normalized_referrer: normalized,
          referrer: normalized ? "https://#{normalized}" : nil,
          user_id: user_id_pool.sample,
          created_at: DEFAULT_RANGE.ago + rand(DEFAULT_RANGE.to_i).seconds,
        }
      end
    end

    def mirror_to_application_requests(rows)
      rows
        .group_by do |row|
          req_type = row[:user_id] ? :page_view_logged_in_browser : :page_view_anon_browser
          [row[:created_at].to_date, req_type]
        end
        .each do |(date, req_type), grouped|
          ::ApplicationRequest.write_cache!(req_type, grouped.size, date)
        end
    end
  end
end
