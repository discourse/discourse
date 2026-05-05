# frozen_string_literal: true

describe "Request tracking" do
  before do
    ApplicationRequest.delete_all
    ApplicationRequest.enable
    CachedCounting.reset
    CachedCounting.enable
    SiteSetting.trigger_browser_pageview_events = true
  end

  after do
    CachedCounting.reset
    ApplicationRequest.disable
    CachedCounting.disable
  end

  describe "pageviews" do
    it "tracks an anonymous visit correctly" do
      events =
        DiscourseEvent.track_events(:browser_pageview) do
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

      event = events[0][:params].last

      expect(event[:user_id]).to be_nil
      expect(event[:url]).to eq("#{Discourse.base_url_no_prefix}/")
      expect(event[:ip_address]).to eq("::1")
      expect(event[:referrer]).to be_blank
      expect(event[:session_id]).to be_present

      events =
        DiscourseEvent.track_events(:browser_pageview) do
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

      event_2 = events[0][:params].last

      expect(event_2[:user_id]).to be_nil
      expect(event_2[:url]).to eq("#{Discourse.base_url_no_prefix}/categories")
      expect(event_2[:ip_address]).to eq("::1")
      expect(event_2[:referrer]).to eq("#{Discourse.base_url_no_prefix}/")
      expect(event_2[:session_id]).to eq(event[:session_id])
    end

    it "tracks a crawler visit correctly" do
      # Can't change playwright user agent for now... so change site settings to make Discourse detect chrome as a crawler
      SiteSetting.crawler_user_agents += "|chrome"

      events =
        DiscourseEvent.track_events(:browser_pageview) do
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
        DiscourseEvent.track_events(:browser_pageview) do
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

      event = events[0][:params].last

      expect(event[:user_id]).to eq(user.id)
      expect(event[:url]).to eq("#{Discourse.base_url_no_prefix}/")
      expect(event[:ip_address]).to eq("::1")
      expect(event[:referrer]).to be_blank
      expect(event[:session_id]).to be_present
      expect(event[:topic_id]).to be_blank

      events =
        DiscourseEvent.track_events(:browser_pageview) do
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

      event_2 = events[0][:params].last

      expect(event_2[:user_id]).to eq(user.id)
      expect(event_2[:url]).to eq("#{Discourse.base_url_no_prefix}/categories")
      expect(event_2[:ip_address]).to eq("::1")
      expect(event_2[:referrer]).to eq("#{Discourse.base_url_no_prefix}/")
      expect(event_2[:session_id]).to eq(event[:session_id])
    end

    it "tracks normal error pages correctly" do
      SiteSetting.bootstrap_error_pages = false

      events =
        DiscourseEvent.track_events(:browser_pageview) do
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
        DiscourseEvent.track_events(:browser_pageview) do
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

      event = events[0][:params].last

      expect(event[:user_id]).to be_nil
      expect(event[:url]).to eq("#{Discourse.base_url_no_prefix}/safe-mode")
      expect(event[:ip_address]).to eq("::1")
      expect(event[:referrer]).to be_blank
      expect(event[:session_id]).to be_present
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
          "page_view_anon_browser_total" => 1,
          "page_view_logged_in_total" => 0,
          "page_view_crawler_total" => 0,
        )
      end
    end

    it "tracks published pages correctly" do
      SiteSetting.enable_page_publishing = true
      Fabricate(:published_page, public: true, slug: "some-page", topic: Fabricate(:post).topic)

      events =
        DiscourseEvent.track_events(:browser_pageview) do
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

      event = events[0][:params].last

      expect(event[:user_id]).to be_nil
      expect(event[:url]).to eq("#{Discourse.base_url_no_prefix}/pub/some-page")
      expect(event[:ip_address]).to eq("::1")
      expect(event[:referrer]).to be_blank
      expect(event[:session_id]).to be_present
    end

    context "when use_beacon_for_browser_page_views is enabled" do
      before { SiteSetting.use_beacon_for_browser_page_views = true }

      it "tracks an anonymous visit correctly" do
        all_events =
          DiscourseEvent.track_events do
            visit "/"
            try_until_success do
              CachedCounting.flush
              expect(
                ApplicationRequest.stats.slice(
                  "page_view_anon_total",
                  "page_view_anon_browser_total",
                  "page_view_anon_browser_beacon_total",
                  "page_view_logged_in_total",
                  "page_view_crawler_total",
                ),
              ).to eq(
                "page_view_anon_total" => 1,
                "page_view_anon_browser_total" => 1,
                "page_view_anon_browser_beacon_total" => 1,
                "page_view_logged_in_total" => 0,
                "page_view_crawler_total" => 0,
              )
            end
          end

        beacon_events = all_events.select { |e| e[:event_name] == :beacon_browser_pageview }
        non_beacon_events = all_events.select { |e| e[:event_name] == :browser_pageview }

        expect(beacon_events.size).to eq(1)
        expect(non_beacon_events.size).to eq(1)

        beacon_event = beacon_events[0][:params].last
        non_beacon_event = non_beacon_events[0][:params].last

        [beacon_event, non_beacon_event].each do |event|
          expect(event[:user_id]).to be_nil
          expect(event[:url]).to eq("#{Discourse.base_url_no_prefix}/")
          expect(event[:ip_address]).to eq("::1")
          expect(event[:referrer]).to be_blank
          expect(event[:session_id]).to be_present
        end

        expect(beacon_event[:session_id]).to eq(non_beacon_event[:session_id])

        all_events =
          DiscourseEvent.track_events do
            find(".nav-item_categories a").click

            CachedCounting.flush
            expect(
              ApplicationRequest.stats.slice(
                "page_view_anon_total",
                "page_view_anon_browser_total",
                "page_view_anon_browser_beacon_total",
                "page_view_logged_in_total",
                "page_view_crawler_total",
              ),
            ).to eq(
              "page_view_anon_total" => 2,
              "page_view_anon_browser_total" => 2,
              "page_view_anon_browser_beacon_total" => 2,
              "page_view_logged_in_total" => 0,
              "page_view_crawler_total" => 0,
            )
          end

        beacon_events_2 = all_events.select { |e| e[:event_name] == :beacon_browser_pageview }
        non_beacon_events_2 = all_events.select { |e| e[:event_name] == :browser_pageview }

        expect(beacon_events_2.size).to eq(1)
        expect(non_beacon_events_2.size).to eq(1)

        beacon_event_2 = beacon_events_2[0][:params].last
        non_beacon_event_2 = non_beacon_events_2[0][:params].last

        [beacon_event_2, non_beacon_event_2].each do |event|
          expect(event[:user_id]).to be_nil
          expect(event[:url]).to eq("#{Discourse.base_url_no_prefix}/categories")
          expect(event[:ip_address]).to eq("::1")
          expect(event[:referrer]).to eq("#{Discourse.base_url}/")
          expect(event[:session_id]).to eq(beacon_event[:session_id])
        end
      end

      it "tracks a logged-in session correctly" do
        user = Fabricate(:user)
        sign_in user

        all_events =
          DiscourseEvent.track_events do
            visit "/"

            try_until_success do
              CachedCounting.flush
              expect(
                ApplicationRequest.stats.slice(
                  "page_view_anon_total",
                  "page_view_anon_browser_total",
                  "page_view_logged_in_total",
                  "page_view_logged_in_browser_total",
                  "page_view_logged_in_browser_beacon_total",
                  "page_view_crawler_total",
                ),
              ).to eq(
                "page_view_anon_total" => 0,
                "page_view_anon_browser_total" => 0,
                "page_view_logged_in_total" => 1,
                "page_view_logged_in_browser_total" => 1,
                "page_view_logged_in_browser_beacon_total" => 1,
                "page_view_crawler_total" => 0,
              )
            end
          end

        beacon_events = all_events.select { |e| e[:event_name] == :beacon_browser_pageview }
        non_beacon_events = all_events.select { |e| e[:event_name] == :browser_pageview }

        expect(beacon_events.size).to eq(1)
        expect(non_beacon_events.size).to eq(1)

        beacon_event = beacon_events[0][:params].last
        non_beacon_event = non_beacon_events[0][:params].last

        [beacon_event, non_beacon_event].each do |event|
          expect(event[:user_id]).to eq(user.id)
          expect(event[:url]).to eq("#{Discourse.base_url_no_prefix}/")
          expect(event[:ip_address]).to eq("::1")
          expect(event[:referrer]).to be_blank
          expect(event[:session_id]).to be_present
          expect(event[:topic_id]).to be_blank
        end

        expect(beacon_event[:session_id]).to eq(non_beacon_event[:session_id])

        all_events =
          DiscourseEvent.track_events do
            find(".nav-item_categories a").click
            CachedCounting.flush
            expect(
              ApplicationRequest.stats.slice(
                "page_view_anon_total",
                "page_view_anon_browser_total",
                "page_view_logged_in_total",
                "page_view_logged_in_browser_total",
                "page_view_logged_in_browser_beacon_total",
                "page_view_crawler_total",
              ),
            ).to eq(
              "page_view_anon_total" => 0,
              "page_view_anon_browser_total" => 0,
              "page_view_logged_in_total" => 2,
              "page_view_logged_in_browser_total" => 2,
              "page_view_logged_in_browser_beacon_total" => 2,
              "page_view_crawler_total" => 0,
            )
          end

        beacon_events_2 = all_events.select { |e| e[:event_name] == :beacon_browser_pageview }
        non_beacon_events_2 = all_events.select { |e| e[:event_name] == :browser_pageview }

        expect(beacon_events_2.size).to eq(1)
        expect(non_beacon_events_2.size).to eq(1)

        beacon_event_2 = beacon_events_2[0][:params].last
        non_beacon_event_2 = non_beacon_events_2[0][:params].last

        [beacon_event_2, non_beacon_event_2].each do |event|
          expect(event[:user_id]).to eq(user.id)
          expect(event[:url]).to eq("#{Discourse.base_url_no_prefix}/categories")
          expect(event[:ip_address]).to eq("::1")
          expect(event[:referrer]).to eq("#{Discourse.base_url}/")
          expect(event[:session_id]).to eq(beacon_event[:session_id])
        end
      end

      it "tracks a crawler visit correctly" do
        SiteSetting.crawler_user_agents += "|chrome"

        all_events =
          DiscourseEvent.track_events do
            visit "/"

            try_until_success do
              CachedCounting.flush
              expect(
                ApplicationRequest.stats.slice(
                  "page_view_anon_total",
                  "page_view_anon_browser_total",
                  "page_view_anon_browser_beacon_total",
                  "page_view_logged_in_total",
                  "page_view_crawler_total",
                ),
              ).to eq(
                "page_view_anon_total" => 0,
                "page_view_anon_browser_total" => 0,
                "page_view_anon_browser_beacon_total" => 0,
                "page_view_logged_in_total" => 0,
                "page_view_crawler_total" => 1,
              )
            end
          end

        beacon_events = all_events.select { |e| e[:event_name] == :beacon_browser_pageview }
        non_beacon_events = all_events.select { |e| e[:event_name] == :browser_pageview }

        expect(beacon_events).to be_blank
        expect(non_beacon_events).to be_blank
      end
    end
  end

  describe "topic views" do
    fab!(:current_user, :user)
    fab!(:topic)
    fab!(:post) { Fabricate(:post, topic: topic) }

    context "when logged in" do
      before { sign_in(current_user) }

      it "tracks user viewing a topic correctly with deferred tracking" do
        events =
          DiscourseEvent.track_events(:browser_pageview) do
            visit topic.url

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

        event = events[0][:params].last

        expect(event[:user_id]).to eq(current_user.id)
        expect(event[:url]).to eq(topic.url)
        expect(event[:ip_address]).to eq("::1")
        expect(event[:referrer]).to be_blank
        expect(event[:session_id]).to be_present
        expect(event[:topic_id]).to eq(topic.id)
      end

      it "tracks user viewing a topic correctly with explicit tracking" do
        visit "/"

        events =
          DiscourseEvent.track_events(:browser_pageview) do
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

        # Find the event for the topic we navigated to (by topic_id) to avoid flakiness
        # from potential timing issues with multiple events
        event = events.find { |e| e[:params].last[:topic_id] == topic.id }&.dig(:params)&.last
        expect(event).to be_present

        expect(event[:user_id]).to eq(current_user.id)
        expect(event[:url]).to eq(topic.url)
        expect(event[:ip_address]).to eq("::1")
        expect(event[:referrer]).to eq("#{Discourse.base_url_no_prefix}/")
        expect(event[:session_id]).to be_present
      end
    end

    context "when anonymous" do
      it "tracks an anonymous user viewing a topic correctly with deferred tracking" do
        events =
          DiscourseEvent.track_events(:browser_pageview) do
            visit topic.url

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

        event = events[0][:params].last

        expect(event[:user_id]).to be_blank
        expect(event[:url]).to eq(topic.url)
        expect(event[:ip_address]).to eq("::1")
        expect(event[:referrer]).to be_blank
        expect(event[:session_id]).to be_present
      end

      it "tracks an anonymous user viewing a topic correctly with explicit tracking" do
        visit "/"

        events =
          DiscourseEvent.track_events(:browser_pageview) do
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

        # Find the event for the topic we navigated to (by topic_id) to avoid flakiness
        # from potential timing issues with multiple events
        event = events.find { |e| e[:params].last[:topic_id] == topic.id }&.dig(:params)&.last
        expect(event).to be_present

        expect(event[:user_id]).to be_blank
        expect(event[:url]).to eq(topic.url)
        expect(event[:ip_address]).to eq("::1")
        expect(event[:referrer]).to eq("#{Discourse.base_url}/")
        expect(event[:session_id]).to be_present
      end
    end

    context "when use_beacon_for_browser_page_views is enabled" do
      before { SiteSetting.use_beacon_for_browser_page_views = true }

      context "when logged in" do
        before { sign_in(current_user) }

        it "tracks topic views correctly via beacon" do
          visit "/"

          all_events =
            DiscourseEvent.track_events do
              find(".topic-list-item .raw-topic-link[data-topic-id='#{topic.id}']").click

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

          beacon_event =
            all_events
              .select { |e| e[:event_name] == :beacon_browser_pageview }
              .find { |e| e[:params].last[:topic_id] == topic.id }
              &.dig(:params)
              &.last
          non_beacon_event =
            all_events
              .select { |e| e[:event_name] == :browser_pageview }
              .find { |e| e[:params].last[:topic_id] == topic.id }
              &.dig(:params)
              &.last

          expect(beacon_event).to be_present
          expect(non_beacon_event).to be_present

          [beacon_event, non_beacon_event].each do |event|
            expect(event[:user_id]).to eq(current_user.id)
            expect(event[:url]).to eq(topic.url)
            expect(event[:ip_address]).to eq("::1")
            expect(event[:referrer]).to eq("#{Discourse.base_url}/")
            expect(event[:session_id]).to be_present
            expect(event[:topic_id]).to eq(topic.id)
          end
        end
      end

      context "when anonymous" do
        let(:discovery) { PageObjects::Pages::Discovery.new }

        it "tracks topic views correctly via beacon" do
          visit "/"

          all_events =
            DiscourseEvent.track_events do
              find(".topic-list-item .raw-topic-link[data-topic-id='#{topic.id}']").click

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

          beacon_event =
            all_events
              .select { |event| event[:event_name] == :beacon_browser_pageview }
              .find { |event| event[:params].last[:topic_id] == topic.id }
              &.dig(:params)
              &.last
          non_beacon_event =
            all_events
              .select { |event| event[:event_name] == :browser_pageview }
              .find { |event| event[:params].last[:topic_id] == topic.id }
              &.dig(:params)
              &.last

          expect(beacon_event).to be_present
          expect(non_beacon_event).to be_present

          [beacon_event, non_beacon_event].each do |event|
            expect(event[:user_id]).to be_blank
            expect(event[:url]).to eq(topic.url)
            expect(event[:ip_address]).to eq("::1")
            expect(event[:referrer]).to eq("#{Discourse.base_url}/")
            expect(event[:session_id]).to be_present
          end
        end

        it "tracks the previous URL as referrer on browser back and forward navigation via beacon" do
          visit "/"
          wait_for_beacon_count(1)

          discovery.topic_list.visit_topic(topic)
          wait_for_beacon_count(2)

          events =
            DiscourseEvent.track_events(:beacon_browser_pageview) do
              page.go_back
              wait_for_beacon_count(3)
            end

          beacon_back_event = events.first[:params].last

          expect(beacon_back_event[:url]).to eq("#{Discourse.base_url_no_prefix}/")
          expect(beacon_back_event[:referrer]).to eq(topic.url)

          events =
            DiscourseEvent.track_events(:beacon_browser_pageview) do
              page.go_forward
              wait_for_beacon_count(4)
            end

          beacon_forward_event = events.first[:params].last

          expect(beacon_forward_event[:url]).to eq(topic.url)
          expect(beacon_forward_event[:referrer]).to eq("#{Discourse.base_url}/")
        end

        def wait_for_beacon_count(count)
          try_until_success do
            CachedCounting.flush
            expect(ApplicationRequest.stats["page_view_anon_browser_beacon_total"]).to eq(count)
          end
        end
      end
    end
  end

  describe "BPV log entries" do
    fab!(:user)
    fab!(:topic)
    fab!(:post) { Fabricate(:post, topic: topic) }

    before do
      SiteSetting.use_beacon_for_browser_page_views = true
      Middleware::RequestTracker.bpv_notifications_enabled = true
    end

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

    shared_examples "logs piggyback and beacon entries on home and topic" do
      it "writes piggyback and beacon entries on each navigation" do
        home_url = "#{Discourse.base_url_no_prefix}/"

        home_entries =
          capture_log_entries(controller: "PageviewController", entries: 2) { visit "/" }

        home_piggyback = home_entries.find { |e| e["action"] == "piggyback" }
        home_beacon = home_entries.find { |e| e["action"] == "beacon" }

        expect(home_piggyback).to include(
          common_fields(
            controller: "PageviewController",
            action: "piggyback",
            path: "/pageview",
            username: expected_username,
            url: home_url,
          ),
        )
        expect(home_beacon).to include(
          common_fields(
            controller: "PageviewController",
            action: "beacon",
            path: "/srv/pv",
            username: expected_username,
            url: home_url,
          ),
        )

        topic_entries =
          capture_log_entries(controller: "PageviewController", entries: 2) do
            find(".topic-list-item .raw-topic-link[data-topic-id='#{topic.id}']").click
          end

        topic_piggyback = topic_entries.find { |e| e["action"] == "piggyback" }
        topic_beacon = topic_entries.find { |e| e["action"] == "beacon" }

        expect(topic_piggyback).to include(
          common_fields(
            controller: "PageviewController",
            action: "piggyback",
            path: "/pageview",
            username: expected_username,
            url: topic.url,
          ),
          "topic_id" => topic.id,
          "referrer" => home_url,
        )
        expect(topic_beacon).to include(
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

        all_session_ids = (home_entries + topic_entries).map { |e| e["session_id"] }.uniq
        expect(all_session_ids.size).to eq(1)
      end
    end

    context "when anonymous" do
      let(:expected_username) { nil }

      include_examples "logs piggyback and beacon entries on home and topic"
    end

    context "when logged in" do
      before { sign_in(user) }
      let(:expected_username) { user.username }

      include_examples "logs piggyback and beacon entries on home and topic"
    end
  end
end
