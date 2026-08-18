# frozen_string_literal: true

RSpec.describe SearchLog, type: :model do
  after { SearchLog.clear_debounce_cache! }

  describe ".log" do
    context "with invalid arguments" do
      it "no search type returns error" do
        status, _ =
          SearchLog.log(term: "bounty hunter", search_type: :missing, ip_address: "127.0.0.1")

        expect(status).to eq(:error)
      end

      it "no IP returns error" do
        status, _ = SearchLog.log(term: "bounty hunter", search_type: :header, ip_address: nil)

        expect(status).to eq(:error)
      end

      it "truncates the `user_agent` attribute if it exceeds #{described_class::MAXIMUM_USER_AGENT_LENGTH} characters" do
        user_agent = "a" * (described_class::MAXIMUM_USER_AGENT_LENGTH + 1)

        status, _ =
          SearchLog.log(
            term: "bounty hunter",
            search_type: :header,
            user_agent:,
            ip_address: "127.0.0.1",
          )

        expect(status).to eq(:created)
        expect(SearchLog.last.user_agent).to eq("a" * described_class::MAXIMUM_USER_AGENT_LENGTH)
      end
    end

    context "when anonymous" do
      it "logs and updates the search" do
        freeze_time
        action, log_id =
          SearchLog.log(
            term: "jabba",
            search_type: :header,
            ip_address: "192.168.0.33",
            user_agent: "Mozilla",
          )
        expect(action).to eq(:created)
        log = SearchLog.find(log_id)
        expect(log.term).to eq("jabba")
        expect(log.search_type).to eq(SearchLog.search_types[:header])
        expect(log.ip_address).to eq("192.168.0.33")
        expect(log.user_agent).to eq("Mozilla")

        action, updated_log_id =
          SearchLog.log(term: "jabba the hut", search_type: :header, ip_address: "192.168.0.33")
        expect(action).to eq(:updated)
        expect(updated_log_id).to eq(log_id)
      end

      it "creates a new search with a different prefix" do
        freeze_time
        action, _ = SearchLog.log(term: "darth", search_type: :header, ip_address: "127.0.0.1")
        expect(action).to eq(:created)

        action, _ = SearchLog.log(term: "anakin", search_type: :header, ip_address: "127.0.0.1")
        expect(action).to eq(:created)
      end

      it "creates a new search with a different ip" do
        freeze_time
        action, _ = SearchLog.log(term: "darth", search_type: :header, ip_address: "127.0.0.1")
        expect(action).to eq(:created)

        action, _ = SearchLog.log(term: "darth", search_type: :header, ip_address: "127.0.0.2")
        expect(action).to eq(:created)
      end
    end

    context "when logged in" do
      fab!(:user)
      let!(:plugin) { Plugin::Instance.new }
      let!(:modifier) { :search_log_can_log }
      let!(:deny_block) { Proc.new { false } }
      let!(:allow_block) { Proc.new { true } }

      it "logs and updates the search" do
        freeze_time
        action, log_id =
          SearchLog.log(
            term: "hello",
            search_type: :full_page,
            ip_address: "192.168.0.1",
            user_agent: "Mozilla",
            user_id: user.id,
          )
        expect(action).to eq(:created)
        log = SearchLog.find(log_id)
        expect(log.term).to eq("hello")
        expect(log.search_type).to eq(SearchLog.search_types[:full_page])
        expect(log.ip_address).to eq(nil)
        expect(log.user_agent).to eq("Mozilla")
        expect(log.user_id).to eq(user.id)

        action, updated_log_id =
          SearchLog.log(
            term: "hello dolly",
            search_type: :header,
            ip_address: "192.168.0.33",
            user_id: user.id,
          )
        expect(action).to eq(:updated)
        expect(updated_log_id).to eq(log_id)
      end

      it "logs again if time has passed" do
        freeze_time(10.minutes.ago)

        action, _ =
          SearchLog.log(
            term: "hello",
            search_type: :full_page,
            ip_address: "192.168.0.1",
            user_id: user.id,
          )
        expect(action).to eq(:created)

        freeze_time(10.minutes.from_now)
        Discourse.redis.del(SearchLog.redis_key(ip_address: "192.168.0.1", user_id: user.id))

        action, _ =
          SearchLog.log(
            term: "hello",
            search_type: :full_page,
            ip_address: "192.168.0.1",
            user_id: user.id,
          )

        expect(action).to eq(:created)
      end

      it "logs again with a different user" do
        freeze_time

        action, _ =
          SearchLog.log(
            term: "hello",
            search_type: :full_page,
            ip_address: "192.168.0.1",
            user_id: user.id,
          )
        expect(action).to eq(:created)

        action, _ =
          SearchLog.log(
            term: "hello dolly",
            search_type: :full_page,
            ip_address: "192.168.0.1",
            user_id: Fabricate(:user).id,
          )
        expect(action).to eq(:created)
      end

      it "allows plugins to control logging" do
        DiscoursePluginRegistry.register_modifier(plugin, modifier, &deny_block)
        action, _ =
          SearchLog.log(
            term: "hello dolly",
            search_type: :full_page,
            ip_address: "192.168.0.1",
            user_id: Fabricate(:user).id,
          )
        expect(action).to_not eq(:created)

        DiscoursePluginRegistry.register_modifier(plugin, modifier, &allow_block)
        action, _ =
          SearchLog.log(
            term: "hello dolly",
            search_type: :full_page,
            ip_address: "192.168.0.1",
            user_id: Fabricate(:user).id,
          )
        expect(action).to eq(:created)
      ensure
        DiscoursePluginRegistry.unregister_modifier(plugin, modifier, &deny_block)
        DiscoursePluginRegistry.unregister_modifier(plugin, modifier, &allow_block)
      end
    end
  end

  describe ".log" do
    it "flags an anonymous search from a known crawler user agent" do
      _status, id =
        SearchLog.log(
          term: "ruby",
          search_type: :header,
          ip_address: "127.0.0.1",
          user_agent: "Googlebot/2.1 (+http://www.google.com/bot.html)",
        )

      expect(SearchLog.find(id).crawler).to eq(true)
    end

    it "flags a logged-in search from a crawler user agent" do
      user = Fabricate(:user)
      _status, id =
        SearchLog.log(
          term: "ruby",
          search_type: :header,
          ip_address: "127.0.0.1",
          user_agent: "Googlebot/2.1 (+http://www.google.com/bot.html)",
          user_id: user.id,
        )

      expect(SearchLog.find(id).crawler).to eq(true)
    end

    it "flags a search from a scripted client that is not a browser" do
      _status, id =
        SearchLog.log(
          term: "ruby",
          search_type: :header,
          ip_address: "127.0.0.1",
          user_agent: "python-requests/2.31.0",
        )

      expect(SearchLog.find(id).crawler).to eq(true)
    end

    it "records the pageview session the search was made from" do
      _status, id =
        SearchLog.log(
          term: "ruby",
          search_type: :header,
          ip_address: "127.0.0.1",
          session_id: "a" * (SearchLog::MAXIMUM_SESSION_ID_LENGTH + 10),
        )

      expect(SearchLog.find(id).session_id).to eq("a" * SearchLog::MAXIMUM_SESSION_ID_LENGTH)
    end

    it "does not flag an anonymous search that arrived without a user agent" do
      _status, id = SearchLog.log(term: "ruby", search_type: :header, ip_address: "127.0.0.1")

      expect(SearchLog.find(id).crawler).to eq(false)
    end

    it "does not flag an anonymous search from a browser user agent" do
      _status, id =
        SearchLog.log(
          term: "ruby",
          search_type: :header,
          ip_address: "127.0.0.1",
          user_agent:
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36",
        )

      expect(SearchLog.find(id).crawler).to eq(false)
    end
  end

  describe ".flag_likely_crawlers!" do
    let(:session_id) { SecureRandom.hex(16) }
    let(:crawler_score) { CrawlerScorer::BOT_SCORE_THRESHOLD + 1 }

    def flag!
      described_class.flag_likely_crawlers!(window_start: 1.hour.ago, window_end: Time.now)
    end

    it "flags a search made from a session scored as a likely crawler" do
      Fabricate(:browser_pageview_event, session_id: session_id, score: crawler_score)
      log = Fabricate(:search_log, user: nil, session_id: session_id, created_at: 30.minutes.ago)

      flag!

      expect(log.reload.likely_crawler).to eq(true)
    end

    it "leaves a search whose session was scored below the crawler threshold" do
      Fabricate(
        :browser_pageview_event,
        session_id: session_id,
        score: CrawlerScorer::BOT_SCORE_THRESHOLD,
      )
      log = Fabricate(:search_log, user: nil, session_id: session_id, created_at: 30.minutes.ago)

      flag!

      expect(log.reload.likely_crawler).to eq(false)
    end

    it "leaves a search that carries no session" do
      Fabricate(:browser_pageview_event, session_id: session_id, score: crawler_score)
      log = Fabricate(:search_log, user: nil, session_id: nil, created_at: 30.minutes.ago)

      flag!

      expect(log.reload.likely_crawler).to eq(false)
    end

    it "leaves a search whose session has no scored pageviews at all" do
      Fabricate(:browser_pageview_event, session_id: SecureRandom.hex(16), score: crawler_score)
      log = Fabricate(:search_log, user: nil, session_id: session_id, created_at: 30.minutes.ago)

      flag!

      expect(log.reload.likely_crawler).to eq(false)
    end

    it "flags a logged-in search whose session is scored as a likely crawler" do
      Fabricate(:browser_pageview_event, session_id: session_id, score: crawler_score)
      log =
        Fabricate(
          :search_log,
          user: Fabricate(:user),
          ip_address: nil,
          session_id: session_id,
          created_at: 30.minutes.ago,
        )

      flag!

      expect(log.reload.likely_crawler).to eq(true)
    end

    it "leaves searches outside the window alone" do
      Fabricate(:browser_pageview_event, session_id: session_id, score: crawler_score)
      log = Fabricate(:search_log, user: nil, session_id: session_id, created_at: 5.hours.ago)

      flag!

      expect(log.reload.likely_crawler).to eq(false)
    end
  end

  describe ".backfill_crawler!" do
    it "flags existing searches from known crawler user agents" do
      crawler =
        Fabricate(
          :search_log,
          user: nil,
          user_agent: "Googlebot/2.1 (+http://www.google.com/bot.html)",
        )
      human = Fabricate(:search_log, user: nil, user_agent: "Mozilla/5.0 (Macintosh) Chrome/120.0")
      no_agent = Fabricate(:search_log, user: nil, user_agent: nil)
      blank_agent = Fabricate(:search_log, user: nil, user_agent: "")
      member = Fabricate(:search_log, user: Fabricate(:user), user_agent: "Googlebot/2.1")

      expect(described_class.backfill_crawler!).to eq(2)

      expect(crawler.reload.crawler).to eq(true)
      expect(human.reload.crawler).to eq(false)
      expect(no_agent.reload.crawler).to eq(false)
      expect(blank_agent.reload.crawler).to eq(false)
      expect(member.reload.crawler).to eq(true)
    end

    it "is idempotent" do
      Fabricate(:search_log, user: nil, user_agent: "Googlebot/2.1")

      described_class.backfill_crawler!

      expect(described_class.backfill_crawler!).to eq(0)
    end
  end

  describe ".term_details" do
    it "should only use the date for the period" do
      time = Time.utc(2019, 5, 23, 18, 15, 30)
      freeze_time(time)

      search_log = Fabricate(:search_log, created_at: time - 1.hour)
      search_log2 = Fabricate(:search_log, created_at: time + 1.hour)

      details = SearchLog.term_details(search_log.term, :daily)

      expect(details[:data].first[:y]).to eq(2)
    end

    it "correctly returns term details" do
      Fabricate(:search_log, term: "ruby")
      Fabricate(:search_log, term: "ruBy", user: Fabricate(:user))
      Fabricate(:search_log, term: "ruby core", ip_address: "127.0.0.3")

      Fabricate(
        :search_log,
        term: "ruBy",
        search_type: SearchLog.search_types[:full_page],
        ip_address: "127.0.0.2",
      )

      term_details = SearchLog.term_details("ruby")
      expect(term_details[:data][0][:y]).to eq(3)

      term_header_details = SearchLog.term_details("ruby", :all, :header)
      expect(term_header_details[:data][0][:y]).to eq(2)

      SearchLog
        .where("lower(term) = ?", "ruby")
        .where(ip_address: "127.0.0.2")
        .update_all(search_result_id: 24)

      term_click_through_details = SearchLog.term_details("ruby", :all, :click_through_only)
      expect(term_click_through_details[:period]).to eq("all")
      expect(term_click_through_details[:data][0][:y]).to eq(1)
    end

    it "returns only non-staff users' searches with the non_staff_only search type" do
      member = Fabricate(:user)
      admin = Fabricate(:admin)
      moderator = Fabricate(:moderator)
      Fabricate(:search_log, term: "ruby", user: member)
      Fabricate(:search_log, term: "ruby", user: admin)
      Fabricate(:search_log, term: "ruby", user: moderator)
      Fabricate(:search_log, term: "ruby", user: nil)

      expect(
        SearchLog.term_details("ruby", :weekly, :non_staff_only)[:data].sum { |point| point[:y] },
      ).to eq(1)
    end

    it "returns non-staff and anonymous searches minus crawlers with the human_only search type" do
      SiteSetting.improved_crawler_detection = true
      member = Fabricate(:user)
      Fabricate(:search_log, term: "ruby", user: member)
      Fabricate(:search_log, term: "ruby", user: Fabricate(:admin))
      Fabricate(:search_log, term: "ruby", user: Fabricate(:moderator))
      Fabricate(:search_log, term: "ruby", user: nil)
      Fabricate(:search_log, term: "ruby", user: nil, crawler: true)

      expect(
        SearchLog.term_details("ruby", :weekly, :human_only)[:data].sum { |point| point[:y] },
      ).to eq(2)
    end
  end

  describe "trending" do
    fab!(:user)
    def log_search(term, **opts)
      SearchLog.log(
        term: term,
        search_type: :header,
        ip_address: "127.0.0.1",
        user_agent:
          "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36",
        **opts,
      )
    end

    before do
      log_search("ruby")
      log_search("php")
      log_search("java")
      log_search("ruby", user_id: user.id)
      log_search("swift")
      log_search("ruby", ip_address: "127.0.0.2")
    end

    it "considers time period" do
      expect(SearchLog.trending.to_a.count).to eq(4)

      SearchLog.where(term: "swift").update_all(created_at: 1.year.ago)
      expect(SearchLog.trending(:monthly).to_a.count).to eq(3)
    end

    it "correctly returns trending data" do
      top_trending = SearchLog.trending.first
      expect(top_trending.term).to eq("ruby")
      expect(top_trending.searches).to eq(3)
      expect(top_trending.click_through).to eq(0)

      SearchLog.where(term: "ruby", ip_address: "127.0.0.1").update_all(search_result_id: 12)
      SearchLog.where(term: "ruby", user_id: user.id).update_all(search_result_id: 12)
      SearchLog.where(term: "ruby", ip_address: "127.0.0.2").update_all(search_result_id: 24)
      top_trending = SearchLog.trending.first
      expect(top_trending.click_through).to eq(3)
    end

    it "returns only non-staff users' searches with the non_staff_only search type" do
      admin = Fabricate(:admin)
      moderator = Fabricate(:moderator)
      Fabricate(:search_log, term: "admin-search", user: admin)
      Fabricate(:search_log, term: "moderator-search", user: moderator)
      Fabricate(:search_log, term: "anonymous-search", user: nil)

      results = SearchLog.trending(:all, :non_staff_only).to_a

      expect(results.map { |trend| [trend.term, trend.searches] }).to eq([["ruby", 1]])
    end

    it "returns non-staff and anonymous searches minus crawlers with the human_only search type" do
      SiteSetting.improved_crawler_detection = true
      Fabricate(:search_log, term: "admin-search", user: Fabricate(:admin))
      Fabricate(:search_log, term: "crawler-search", user: nil, crawler: true)

      results = SearchLog.trending(:all, :human_only).to_a

      expect(results.map { |trend| [trend.term, trend.searches] }).to eq(
        [["ruby", 3], ["java", 1], ["php", 1], ["swift", 1]],
      )
    end

    it "keeps anonymous searches minus known crawlers for human_only while crawler detection is disabled" do
      SiteSetting.improved_crawler_detection = false
      Fabricate(:search_log, term: "admin-search", user: Fabricate(:admin))
      Fabricate(:search_log, term: "anonymous-search", user: nil)
      Fabricate(:search_log, term: "crawler-search", user: nil, crawler: true)
      Fabricate(:search_log, term: "scored-crawler-search", user: nil, likely_crawler: true)

      results = SearchLog.trending(:all, :human_only).to_a

      expect(results.map { |trend| [trend.term, trend.searches] }).to eq(
        [
          ["ruby", 3],
          ["anonymous-search", 1],
          ["java", 1],
          ["php", 1],
          ["scored-crawler-search", 1],
          ["swift", 1],
        ],
      )
    end
  end

  describe "clean_up" do
    it "will remove old logs" do
      SearchLog.log(term: "jawa", search_type: :header, ip_address: "127.0.0.1")
      SearchLog.log(term: "jedi", search_type: :header, ip_address: "127.0.0.1")
      SearchLog.log(term: "rey", search_type: :header, ip_address: "127.0.0.1")
      SearchLog.log(term: "finn", search_type: :header, ip_address: "127.0.0.1")

      SiteSetting.search_query_log_max_size = 5
      SearchLog.clean_up
      expect(SearchLog.count).to eq(4)

      SiteSetting.search_query_log_max_size = 2
      SearchLog.clean_up
      expect(SearchLog.count).to eq(2)
      expect(SearchLog.where(term: "rey").first).to be_present
      expect(SearchLog.where(term: "finn").first).to be_present
    end
  end
end
