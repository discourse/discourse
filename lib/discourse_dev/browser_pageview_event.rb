# frozen_string_literal: true

require "discourse_dev"

module DiscourseDev
  class BrowserPageviewEvent
    DEFAULT_COUNT = 1500
    BATCH_SIZE = 10_000
    private_constant :BATCH_SIZE

    DESTINATIONS = %w[
      /
      /latest
      /top
      /categories
      /t/welcome-to-discourse/1
      /t/product-feedback/2
      /search
      /tags
    ].freeze

    USER_AGENTS = [
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/126.0",
      "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 Version/17.5 Mobile/15E148 Safari/604.1",
      "Mozilla/5.0 (X11; Linux x86_64) Gecko/20100101 Firefox/127.0",
      "Mozilla/5.0 (compatible; diagnostic traffic prototype)",
    ].freeze

    NETWORKS = [
      [64_500, "192.0.2", "Example Broadband"],
      [64_501, "198.51.100", "Example Cloud"],
      [64_502, "203.0.113", "Example Mobile"],
      [nil, "100.64.0", nil],
    ].freeze

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

      request_counts = Hash.new(0)
      inserted_count = 0

      while inserted_count < count
        rows = build_rows([BATCH_SIZE, count - inserted_count].min)
        ::BrowserPageviewEvent.insert_all(rows)
        collect_application_request_counts(rows, request_counts)
        inserted_count += rows.size
        puts "Inserted #{inserted_count} of #{count} events." if (inserted_count % 100_000).zero?
      end

      mirror_to_application_requests(request_counts)

      puts "Enabled persist_browser_pageview_events and inserted #{inserted_count} events."
      inserted_count
    end

    def self.populate!(count: nil)
      new(count: count || DEFAULT_COUNT).populate!
    end

    private

    attr_reader :count

    def build_rows(batch_size)
      country_pool = COUNTRY_WEIGHTS.flat_map { |code, weight| [code] * weight }
      user_ids = ::User.real.limit(20).pluck(:id)
      user_id_pool = user_ids + ([nil] * [user_ids.size / 4, 1].max)
      range_start = 29.days.ago.beginning_of_day
      range_seconds = (Time.current - range_start).to_i

      Array.new(batch_size) do
        destination = DESTINATIONS.sample
        normalized_referrer = REFERRERS.sample
        asn, network, asn_organization = NETWORKS.sample
        user_agent = USER_AGENTS.sample
        query = rand < 0.35 ? "?utm_source=prototype&visit=#{rand(100)}" : ""
        fragment = rand < 0.15 ? "#post_#{rand(1..20)}" : ""

        {
          url: "https://forum.example.com#{destination}/#{query}#{fragment}",
          normalized_url: destination,
          ip_address: "#{network}.#{rand(1..254)}",
          user_agent:,
          browser_family: ::BrowserDetection.browser(user_agent).to_s,
          session_id: SecureRandom.hex(16),
          country_code: country_pool.sample,
          asn:,
          asn_organization:,
          normalized_referrer:,
          referrer: normalized_referrer ? "https://#{normalized_referrer}" : nil,
          normalized_referrer_version: ::BrowserPageviewReferrerInspector::VERSION,
          user_id: user_id_pool.sample,
          source: ::BrowserPageviewEvent.rollup_source,
          created_at: range_start + rand(range_seconds).seconds,
        }
      end
    end

    def collect_application_request_counts(rows, request_counts)
      rows.each do |row|
        req_type = row[:user_id] ? :page_view_logged_in_browser : :page_view_anon_browser
        request_counts[[row[:created_at].to_date, req_type]] += 1
      end
    end

    def mirror_to_application_requests(request_counts)
      request_counts.each do |(date, req_type), request_count|
        ::ApplicationRequest.write_cache!(req_type, request_count, date)
      end
    end
  end
end
