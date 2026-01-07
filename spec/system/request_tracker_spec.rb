# frozen_string_literal: true

describe "Request tracking", type: :system do
  before do
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
            expect(ApplicationRequest.stats).to include(
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
            expect(ApplicationRequest.stats).to include(
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
            expect(ApplicationRequest.stats).to include(
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
            expect(ApplicationRequest.stats).to include(
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
            expect(ApplicationRequest.stats).to include(
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
            expect(ApplicationRequest.stats).to include(
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
        expect(ApplicationRequest.stats).to include(
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
            expect(ApplicationRequest.stats).to include(
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
        expect(ApplicationRequest.stats).to include(
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
        expect(ApplicationRequest.stats).to include(
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
            expect(ApplicationRequest.stats).to include(
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
        expect(event[:url]).to eq("#{Discourse.base_url_no_prefix}/t/#{topic.slug}/#{topic.id}")
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

        event = events[0][:params].last

        expect(event[:user_id]).to eq(current_user.id)
        expect(event[:url]).to eq("#{Discourse.base_url_no_prefix}/t/#{topic.slug}/#{topic.id}")
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
        expect(event[:url]).to eq("#{Discourse.base_url_no_prefix}/t/#{topic.slug}/#{topic.id}")
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

        event = events[0][:params].last

        expect(event[:user_id]).to be_blank
        expect(event[:url]).to eq("#{Discourse.base_url_no_prefix}/t/#{topic.slug}/#{topic.id}")
        expect(event[:ip_address]).to eq("::1")
        expect(event[:referrer]).to eq("#{Discourse.base_url_no_prefix}/")
        expect(event[:session_id]).to be_present
      end
    end
  end
end
