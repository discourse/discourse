# frozen_string_literal: true

describe "Request tracking", type: :system do
  before do
    ApplicationRequest.enable
    CachedCounting.reset
    CachedCounting.enable
  end

  after do
    CachedCounting.reset
    ApplicationRequest.disable
    CachedCounting.disable
    DiscourseEvent.all_off(:page_visited)
  end

  describe "pageviews" do
    it "tracks an anonymous visit correctly" do
      events = []
      DiscourseEvent.on(:page_visited) { |payload| events << payload }

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

      expect(events.size).to eq(1)
      event = events.last

      expect(event[:user_id]).to be_nil
      expect(event[:url]).to eq("http://localhost:31337/")
      expect(event[:ip_address]).to eq("::1")
      expect(event[:referrer]).to be_blank
      expect(event[:session_id]).to be_present

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

      expect(events.size).to eq(2)
      event = events.last

      expect(event[:user_id]).to be_nil
      expect(event[:url]).to eq("http://localhost:31337/categories")
      expect(event[:ip_address]).to eq("::1")
      expect(event[:referrer]).to eq("http://localhost:31337/")
      expect(event[:session_id]).to eq(events.first[:session_id])
    end

    it "tracks a crawler visit correctly" do
      # Can't change playwright user agent for now... so change site settings to make Discourse detect chrome as a crawler
      SiteSetting.crawler_user_agents += "|chrome"

      events = []
      DiscourseEvent.on(:page_visited) { |payload| events << payload }

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

      expect(events).to be_blank
    end

    it "tracks a logged-in session correctly" do
      user = Fabricate(:user)
      sign_in user

      events = []
      DiscourseEvent.on(:page_visited) { |payload| events << payload }

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

      expect(events.size).to eq(1)
      event = events.last

      expect(event[:user_id]).to eq(user.id)
      expect(event[:url]).to eq("http://localhost:31337/")
      expect(event[:ip_address]).to eq("::1")
      expect(event[:referrer]).to be_blank
      expect(event[:session_id]).to be_present
      expect(event[:topic_id]).to be_blank

      expect(events.size).to eq(1)
      event = events.last

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

      expect(events.size).to eq(2)
      event = events.last

      expect(event[:user_id]).to eq(user.id)
      expect(event[:url]).to eq("http://localhost:31337/categories")
      expect(event[:ip_address]).to eq("::1")
      expect(event[:referrer]).to eq("http://localhost:31337/")
      expect(event[:session_id]).to eq(events.first[:session_id])
    end

    it "tracks normal error pages correctly" do
      SiteSetting.bootstrap_error_pages = false

      events = []
      DiscourseEvent.on(:page_visited) { |payload| events << payload }

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
      events = []
      DiscourseEvent.on(:page_visited) { |payload| events << payload }

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

      expect(events.size).to eq(1)
      event = events.last

      expect(event[:user_id]).to be_nil
      expect(event[:url]).to eq("http://localhost:31337/safe-mode")
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
      page =
        Fabricate(:published_page, public: true, slug: "some-page", topic: Fabricate(:post).topic)

      events = []
      DiscourseEvent.on(:page_visited) { |payload| events << payload }

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

      expect(events.size).to eq(1)
      event = events.last

      expect(event[:user_id]).to be_nil
      expect(event[:url]).to eq("http://localhost:31337/pub/some-page")
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
        events = []
        DiscourseEvent.on(:page_visited) { |payload| events << payload }

        visit topic.url

        try_until_success do
          CachedCounting.flush
          expect(TopicViewItem.exists?(topic_id: topic.id, user_id: current_user.id)).to eq(true)
          expect(
            TopicViewStat.exists?(
              topic_id: topic.id,
              viewed_at: Time.zone.now.to_date,
              anonymous_views: 0,
              logged_in_views: 1,
            ),
          ).to eq(true)
        end

        expect(events.size).to eq(1)
        event = events.last

        expect(event[:user_id]).to eq(current_user.id)
        expect(event[:url]).to eq("http://localhost:31337/t/#{topic.slug}/#{topic.id}")
        expect(event[:ip_address]).to eq("::1")
        expect(event[:referrer]).to be_blank
        expect(event[:session_id]).to be_present
        expect(event[:topic_id]).to eq(topic.id.to_s)
      end

      it "tracks user viewing a topic correctly with explicit tracking" do
        visit "/"

        events = []
        DiscourseEvent.on(:page_visited) { |payload| events << payload }

        find(".topic-list-item .raw-topic-link[data-topic-id='#{topic.id}']").click

        try_until_success do
          CachedCounting.flush
          expect(TopicViewItem.exists?(topic_id: topic.id, user_id: current_user.id)).to eq(true)
          expect(
            TopicViewStat.exists?(
              topic_id: topic.id,
              viewed_at: Time.zone.now.to_date,
              anonymous_views: 0,
              logged_in_views: 1,
            ),
          ).to eq(true)
        end

        expect(events.size).to eq(1)
        event = events.last

        expect(event[:user_id]).to eq(current_user.id)
        expect(event[:url]).to eq("http://localhost:31337/t/#{topic.slug}/#{topic.id}")
        expect(event[:ip_address]).to eq("::1")
        expect(event[:referrer]).to eq("http://localhost:31337/")
        expect(event[:session_id]).to be_present
      end
    end

    context "when anonymous" do
      it "tracks an anonymous user viewing a topic correctly with deferred tracking" do
        events = []
        DiscourseEvent.on(:page_visited) { |payload| events << payload }

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

        expect(events.size).to eq(1)
        event = events.last

        expect(event[:user_id]).to be_blank
        expect(event[:url]).to eq("http://localhost:31337/t/#{topic.slug}/#{topic.id}")
        expect(event[:ip_address]).to eq("::1")
        expect(event[:referrer]).to be_blank
        expect(event[:session_id]).to be_present
      end

      it "tracks an anonymous user viewing a topic correctly with explicit tracking" do
        visit "/"

        events = []
        DiscourseEvent.on(:page_visited) { |payload| events << payload }

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

        expect(events.size).to eq(1)
        event = events.last

        expect(event[:user_id]).to be_blank
        expect(event[:url]).to eq("http://localhost:31337/t/#{topic.slug}/#{topic.id}")
        expect(event[:ip_address]).to eq("::1")
        expect(event[:referrer]).to eq("http://localhost:31337/")
        expect(event[:session_id]).to be_present
      end
    end
  end
end
