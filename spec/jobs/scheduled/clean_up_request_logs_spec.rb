# frozen_string_literal: true

RSpec.describe Jobs::CleanUpRequestLogs do
  describe "#execute" do
    context "when page view logging is enabled" do
      before { SiteSetting.enable_page_view_logging = true }

      it "deletes old browser page views" do
        freeze_time

        _old_view = BrowserPageView.create!(path: "/old", is_mobile: false, created_at: 31.days.ago)
        _recent_view =
          BrowserPageView.create!(path: "/recent", is_mobile: false, created_at: 1.day.ago)

        described_class.new.execute({})

        expect(BrowserPageView.where(path: "/old").exists?).to eq(false)
        expect(BrowserPageView.where(path: "/recent").exists?).to eq(true)
      end

      it "respects retention days setting" do
        SiteSetting.page_view_logging_retention_days = 7
        freeze_time

        _week_old =
          BrowserPageView.create!(path: "/week-old", is_mobile: false, created_at: 8.days.ago)
        _recent = BrowserPageView.create!(path: "/recent", is_mobile: false, created_at: 5.days.ago)

        described_class.new.execute({})

        expect(BrowserPageView.where(path: "/week-old").exists?).to eq(false)
        expect(BrowserPageView.where(path: "/recent").exists?).to eq(true)
      end
    end

    context "when page view logging is disabled" do
      before { SiteSetting.enable_page_view_logging = false }

      it "does not clean up browser page views" do
        freeze_time

        _old_view = BrowserPageView.create!(path: "/old", is_mobile: false, created_at: 31.days.ago)

        described_class.new.execute({})

        expect(BrowserPageView.where(path: "/old").exists?).to eq(true)
      end
    end

    context "when API request logging is enabled" do
      before { SiteSetting.enable_api_request_logging = true }

      it "deletes old API request logs" do
        freeze_time

        _old_log =
          ApiRequestLog.create!(
            path: "/old",
            http_status: 200,
            is_user_api: false,
            created_at: 31.days.ago,
          )
        _recent_log =
          ApiRequestLog.create!(
            path: "/recent",
            http_status: 200,
            is_user_api: false,
            created_at: 1.day.ago,
          )

        described_class.new.execute({})

        expect(ApiRequestLog.where(path: "/old").exists?).to eq(false)
        expect(ApiRequestLog.where(path: "/recent").exists?).to eq(true)
      end

      it "respects retention days setting" do
        SiteSetting.api_request_logging_retention_days = 7
        freeze_time

        _week_old =
          ApiRequestLog.create!(
            path: "/week-old",
            http_status: 200,
            is_user_api: false,
            created_at: 8.days.ago,
          )
        _recent =
          ApiRequestLog.create!(
            path: "/recent",
            http_status: 200,
            is_user_api: false,
            created_at: 5.days.ago,
          )

        described_class.new.execute({})

        expect(ApiRequestLog.where(path: "/week-old").exists?).to eq(false)
        expect(ApiRequestLog.where(path: "/recent").exists?).to eq(true)
      end
    end

    context "when API request logging is disabled" do
      before { SiteSetting.enable_api_request_logging = false }

      it "does not clean up API request logs" do
        freeze_time

        _old_log =
          ApiRequestLog.create!(
            path: "/old",
            http_status: 200,
            is_user_api: false,
            created_at: 31.days.ago,
          )

        described_class.new.execute({})

        expect(ApiRequestLog.where(path: "/old").exists?).to eq(true)
      end
    end
  end
end
