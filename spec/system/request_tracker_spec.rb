# frozen_string_literal: true

describe "Request tracking" do
  before do
    ApplicationRequest.delete_all
    ApplicationRequest.enable
    CachedCounting.reset
    CachedCounting.enable
  end

  after do
    CachedCounting.reset
    ApplicationRequest.disable
    CachedCounting.disable
  end

  let(:pageview_tracking) { PageObjects::Pages::PageviewTracking.new }

  def track_pageview_events
    last_event_id = BrowserPageviewEvent.maximum(:id) || 0
    yield
    BrowserPageviewEvent.where("id > ?", last_event_id).order(:id).to_a
  end

  describe "pageviews" do
    it "tracks an anonymous visit correctly" do
      events =
        track_pageview_events do
          visit "/"
          try_until_success do
            CachedCounting.flush
            expect(
              ApplicationRequest.stats.slice(
                "page_view_anon_total",
                "page_view_anon_browser_total",
                "page_view_logged_in_total",
                "page_view_crawler_total",
              ),
            ).to eq(
              "page_view_anon_total" => 1,
              "page_view_anon_browser_total" => 1,
              "page_view_logged_in_total" => 0,
              "page_view_crawler_total" => 0,
            )
          end
        end

      event = events.first

      expect(event.user_id).to be_nil
      expect(event.url).to eq("#{Discourse.base_url_no_prefix}/")
      expect(event.ip_address.to_s).to eq("::1")
      expect(event.referrer).to be_blank
      expect(event.session_id).to eq(pageview_tracking.session_id)

      events =
        track_pageview_events do
          find(".nav-item_categories a").click

          try_until_success do
            CachedCounting.flush
            expect(
              ApplicationRequest.stats.slice(
                "page_view_anon_total",
                "page_view_anon_browser_total",
                "page_view_logged_in_total",
                "page_view_crawler_total",
              ),
            ).to eq(
              "page_view_anon_total" => 2,
              "page_view_anon_browser_total" => 2,
              "page_view_logged_in_total" => 0,
              "page_view_crawler_total" => 0,
            )
          end
        end

      event_2 = events.first

      expect(event_2.user_id).to be_nil
      expect(event_2.url).to eq("#{Discourse.base_url_no_prefix}/categories")
      expect(event_2.ip_address.to_s).to eq("::1")
      expect(event_2.referrer).to eq("#{Discourse.base_url_no_prefix}/")
      expect(event_2.session_id).to eq(event.session_id)
    end

    it "tracks a crawler visit correctly" do
      # Can't change playwright user agent for now... so change site settings to make Discourse detect chrome as a crawler
      SiteSetting.crawler_user_agents += "|chrome"

      events =
        track_pageview_events do
          visit "/"

          try_until_success do
            CachedCounting.flush
            expect(
              ApplicationRequest.stats.slice(
                "page_view_anon_total",
                "page_view_anon_browser_total",
                "page_view_logged_in_total",
                "page_view_crawler_total",
              ),
            ).to eq(
              "page_view_anon_total" => 0,
              "page_view_anon_browser_total" => 0,
              "page_view_logged_in_total" => 0,
              "page_view_crawler_total" => 1,
            )
          end
        end

      expect(events).to be_blank
    end

    it "tracks a logged-in session correctly" do
      user = Fabricate(:user)
      sign_in user

      events =
        track_pageview_events do
          visit "/"

          try_until_success do
            CachedCounting.flush
            expect(
              ApplicationRequest.stats.slice(
                "page_view_anon_total",
                "page_view_anon_browser_total",
                "page_view_logged_in_total",
                "page_view_crawler_total",
                "page_view_logged_in_browser_total",
              ),
            ).to eq(
              "page_view_anon_total" => 0,
              "page_view_anon_browser_total" => 0,
              "page_view_logged_in_total" => 1,
              "page_view_crawler_total" => 0,
              "page_view_logged_in_browser_total" => 1,
            )
          end
        end

      event = events.first

      expect(event.user_id).to eq(user.id)
      expect(event.url).to eq("#{Discourse.base_url_no_prefix}/")
      expect(event.ip_address.to_s).to eq("::1")
      expect(event.referrer).to be_blank
      expect(event.session_id).to be_present
      expect(event.topic_id).to be_blank
      expect(event.language).to eq(page.evaluate_script("navigator.language"))

      events =
        track_pageview_events do
          find(".nav-item_categories a").click
          try_until_success do
            CachedCounting.flush
            expect(
              ApplicationRequest.stats.slice(
                "page_view_anon_total",
                "page_view_anon_browser_total",
                "page_view_logged_in_total",
                "page_view_crawler_total",
                "page_view_logged_in_browser_total",
              ),
            ).to eq(
              "page_view_anon_total" => 0,
              "page_view_anon_browser_total" => 0,
              "page_view_logged_in_total" => 2,
              "page_view_crawler_total" => 0,
              "page_view_logged_in_browser_total" => 2,
            )
          end
        end

      event_2 = events.first

      expect(event_2.user_id).to eq(user.id)
      expect(event_2.url).to eq("#{Discourse.base_url_no_prefix}/categories")
      expect(event_2.ip_address.to_s).to eq("::1")
      expect(event_2.referrer).to eq("#{Discourse.base_url_no_prefix}/")
      expect(event_2.session_id).to eq(event.session_id)
    end

    it "tracks normal error pages correctly" do
      SiteSetting.bootstrap_error_pages = false

      events =
        track_pageview_events do
          visit "/foobar"

          try_until_success do
            CachedCounting.flush

            # Does not count error as a pageview
            expect(
              ApplicationRequest.stats.slice(
                "http_4xx_total",
                "page_view_anon_total",
                "page_view_anon_browser_total",
                "page_view_logged_in_total",
                "page_view_crawler_total",
              ),
            ).to eq(
              "http_4xx_total" => 1,
              "page_view_anon_total" => 0,
              "page_view_anon_browser_total" => 0,
              "page_view_logged_in_total" => 0,
              "page_view_crawler_total" => 0,
            )
          end
        end

      expect(events).to be_blank

      click_logo

      try_until_success do
        CachedCounting.flush
        expect(
          ApplicationRequest.stats.slice(
            "http_4xx_total",
            "page_view_anon_total",
            "page_view_anon_browser_total",
            "page_view_logged_in_total",
            "page_view_crawler_total",
          ),
        ).to eq(
          "http_4xx_total" => 1,
          "page_view_anon_total" => 1,
          "page_view_anon_browser_total" => 1,
          "page_view_logged_in_total" => 0,
          "page_view_crawler_total" => 0,
        )
      end
    end

    it "tracks non-ember pages correctly" do
      events =
        track_pageview_events do
          visit "/safe-mode"

          try_until_success do
            CachedCounting.flush

            # Does not count error as a pageview
            expect(
              ApplicationRequest.stats.slice(
                "page_view_anon_total",
                "page_view_anon_browser_total",
                "page_view_logged_in_total",
                "page_view_crawler_total",
              ),
            ).to eq(
              "page_view_anon_total" => 1,
              "page_view_anon_browser_total" => 1,
              "page_view_logged_in_total" => 0,
              "page_view_crawler_total" => 0,
            )
          end
        end

      event = events.first

      expect(event.user_id).to be_nil
      expect(event.url).to eq("#{Discourse.base_url_no_prefix}/safe-mode")
      expect(event.ip_address.to_s).to eq("::1")
      expect(event.referrer).to be_blank
      expect(event.session_id).to be_present
    end

    it "tracks bootstrapped error pages correctly" do
      SiteSetting.bootstrap_error_pages = true

      visit "/foobar"

      try_until_success do
        CachedCounting.flush

        # Does not count error as a pageview
        expect(
          ApplicationRequest.stats.slice(
            "http_4xx_total",
            "page_view_anon_total",
            "page_view_anon_browser_total",
            "page_view_logged_in_total",
            "page_view_crawler_total",
          ),
        ).to eq(
          "http_4xx_total" => 1,
          "page_view_anon_total" => 0,
          "page_view_anon_browser_total" => 0,
          "page_view_logged_in_total" => 0,
          "page_view_crawler_total" => 0,
        )
      end

      click_logo

      try_until_success do
        CachedCounting.flush
        expect(
          ApplicationRequest.stats.slice(
            "http_4xx_total",
            "page_view_anon_total",
            "page_view_anon_browser_total",
            "page_view_logged_in_total",
            "page_view_crawler_total",
          ),
        ).to eq(
          "http_4xx_total" => 1,
          "page_view_anon_total" => 1,
          "page_view_anon_browser_total" => 0,
          "page_view_logged_in_total" => 0,
          "page_view_crawler_total" => 0,
        )
      end
    end

    it "tracks published pages correctly" do
      SiteSetting.enable_page_publishing = true
      Fabricate(:published_page, public: true, slug: "some-page", topic: Fabricate(:post).topic)

      events =
        track_pageview_events do
          visit "/pub/some-page"

          try_until_success do
            CachedCounting.flush

            # Does not count error as a pageview
            expect(
              ApplicationRequest.stats.slice(
                "page_view_anon_total",
                "page_view_anon_browser_total",
                "page_view_logged_in_total",
                "page_view_crawler_total",
              ),
            ).to eq(
              "page_view_anon_total" => 1,
              "page_view_anon_browser_total" => 1,
              "page_view_logged_in_total" => 0,
              "page_view_crawler_total" => 0,
            )
          end
        end

      event = events.first

      expect(event.user_id).to be_nil
      expect(event.url).to eq("#{Discourse.base_url_no_prefix}/pub/some-page")
      expect(event.ip_address.to_s).to eq("::1")
      expect(event.referrer).to be_blank
      expect(event.session_id).to be_present
    end
  end

  describe "topic views" do
    fab!(:current_user, :user)
    fab!(:topic)
    fab!(:post) { Fabricate(:post, topic: topic) }

    context "when logged in" do
      before { sign_in(current_user) }

      it "tracks a logged-in topic view during in-app navigation" do
        visit "/"

        events =
          track_pageview_events do
            find(".topic-list-item .raw-topic-link[data-topic-id='#{topic.id}']").click

            try_until_success do
              CachedCounting.flush
              expect(TopicViewItem.exists?(topic_id: topic.id, user_id: current_user.id)).to eq(
                true,
              )
              expect(
                TopicViewStat.exists?(
                  topic_id: topic.id,
                  viewed_at: Time.zone.now.to_date,
                  anonymous_views: 0,
                  logged_in_views: 1,
                ),
              ).to eq(true)
            end
          end

        event = events.find { |pageview_event| pageview_event.topic_id == topic.id }
        expect(event).to be_present

        expect(event.user_id).to eq(current_user.id)
        expect(event.url).to eq(topic.url)
        expect(event.ip_address.to_s).to eq("::1")
        expect(event.referrer).to eq("#{Discourse.base_url_no_prefix}/")
        expect(event.session_id).to be_present
        expect(event.language).to eq(page.evaluate_script("navigator.language"))
      end
    end

    context "when anonymous" do
      it "tracks an anonymous topic view during in-app navigation" do
        visit "/"

        events =
          track_pageview_events do
            find(".topic-list-item .raw-topic-link[data-topic-id='#{topic.id}']").click

            try_until_success do
              CachedCounting.flush
              expect(TopicViewItem.exists?(topic_id: topic.id, user_id: nil)).to eq(true)
              expect(
                TopicViewStat.exists?(
                  topic_id: topic.id,
                  viewed_at: Time.zone.now.to_date,
                  anonymous_views: 1,
                  logged_in_views: 0,
                ),
              ).to eq(true)
            end
          end

        event = events.find { |pageview_event| pageview_event.topic_id == topic.id }
        expect(event).to be_present

        expect(event.user_id).to be_blank
        expect(event.url).to eq(topic.url)
        expect(event.ip_address.to_s).to eq("::1")
        expect(event.referrer).to eq("#{Discourse.base_url}/")
        expect(event.session_id).to be_present
      end
    end

    context "when navigating with beacons" do
      context "when anonymous" do
        let(:discovery) { PageObjects::Pages::Discovery.new }

        it "tracks the previous URL as referrer on browser back and forward navigation via beacon" do
          visit "/"
          wait_for_beacon_count(1)

          discovery.topic_list.visit_topic(topic)
          wait_for_beacon_count(2)

          events =
            track_pageview_events do
              page.go_back
              wait_for_beacon_count(3)
            end

          beacon_back_event = events.first

          expect(beacon_back_event.url).to eq("#{Discourse.base_url_no_prefix}/")
          expect(beacon_back_event.referrer).to eq(topic.url)

          events =
            track_pageview_events do
              page.go_forward
              wait_for_beacon_count(4)
            end

          beacon_forward_event = events.first

          expect(beacon_forward_event.url).to eq(topic.url)
          expect(beacon_forward_event.referrer).to eq("#{Discourse.base_url}/")
        end

        it "tracks browser pageviews when sorting a topic list" do
          visit "/latest"
          wait_for_beacon_count(1)

          discovery.topic_list_header.click_sort_by("views")

          expect(page).to have_current_path("/latest?ascending=false&order=views")
          wait_for_beacon_count(2)
        end

        def wait_for_beacon_count(count)
          try_until_success do
            CachedCounting.flush
            expect(ApplicationRequest.stats["page_view_anon_browser_total"]).to eq(count)
          end
        end
      end
    end
  end

  describe "BPV log entries" do
    fab!(:user)
    fab!(:topic)
    fab!(:post) { Fabricate(:post, topic: topic) }

    before { Middleware::RequestTracker.bpv_notifications_enabled = true }

    after { Middleware::RequestTracker.bpv_notifications_enabled = false }

    def common_fields(controller:, action:, path:, username:, url:)
      {
        "controller" => controller,
        "action" => action,
        "method" => "POST",
        "path" => path,
        "status" => 204,
        "format" => "json",
        "tracked" => true,
        "ip" => be_present,
        "url" => url,
        "session_id" => be_present,
        "username" => username ? eq(username) : be_blank,
      }
    end

    shared_examples "logs beacon entries on home and topic" do
      it "writes a beacon entry on each navigation" do
        home_url = "#{Discourse.base_url_no_prefix}/"

        home_entries =
          capture_log_entries(controller: "PageviewController", entries: 1) { visit "/" }

        expect(home_entries.first).to include(
          common_fields(
            controller: "PageviewController",
            action: "beacon",
            path: "/srv/pv",
            username: expected_username,
            url: home_url,
          ),
        )

        topic_entries =
          capture_log_entries(controller: "PageviewController", entries: 1) do
            find(".topic-list-item .raw-topic-link[data-topic-id='#{topic.id}']").click
          end

        expect(topic_entries.first).to include(
          common_fields(
            controller: "PageviewController",
            action: "beacon",
            path: "/srv/pv",
            username: expected_username,
            url: topic.url,
          ),
          "topic_id" => topic.id,
          "referrer" => home_url,
        )

        expect((home_entries + topic_entries).map { |entry| entry["session_id"] }.uniq.size).to eq(
          1,
        )
      end
    end

    context "when anonymous" do
      let(:expected_username) { nil }

      include_examples "logs beacon entries on home and topic"
    end

    context "when logged in" do
      before { sign_in(user) }
      let(:expected_username) { user.username }

      include_examples "logs beacon entries on home and topic"
    end
  end
end
