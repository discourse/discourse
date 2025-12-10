# frozen_string_literal: true

RSpec.describe BrowserPageView do
  describe ".log!" do
    let(:data) do
      {
        current_user_id: 1,
        topic_id: 123,
        path: "/t/test-topic/123",
        query_string: "page=2",
        route: "topics#show",
        user_agent: "Mozilla/5.0 Test Browser",
        request_remote_ip: "192.168.1.1",
        referrer: "https://google.com",
        is_crawler: false,
        is_mobile: true,
        is_api: false,
        is_user_api: false,
        status: 200,
      }
    end

    it "creates a browser page view record" do
      expect { BrowserPageView.log!(data) }.to change { BrowserPageView.count }.by(1)

      view = BrowserPageView.order(:created_at).last
      expect(view.user_id).to eq(1)
      expect(view.topic_id).to eq(123)
      expect(view.path).to eq("/t/test-topic/123")
      expect(view.query_string).to eq("page=2")
      expect(view.route).to eq("topics#show")
      expect(view.user_agent).to eq("Mozilla/5.0 Test Browser")
      expect(view.ip_address.to_s).to eq("192.168.1.1")
      expect(view.referrer).to eq("https://google.com")
      expect(view.is_crawler).to eq(false)
      expect(view.is_mobile).to eq(true)
      expect(view.is_api).to eq(false)
      expect(view.is_user_api).to eq(false)
      expect(view.http_status).to eq(200)
      expect(view.created_at).to be_present
    end

    it "truncates long path values" do
      long_path = "a" * 2000
      data[:path] = long_path

      BrowserPageView.log!(data)
      view = BrowserPageView.order(:created_at).last

      expect(view.path.length).to eq(1024)
    end

    it "truncates long query_string values" do
      long_query = "a" * 2000
      data[:query_string] = long_query

      BrowserPageView.log!(data)
      view = BrowserPageView.order(:created_at).last

      expect(view.query_string.length).to eq(1024)
    end

    it "truncates long user_agent values" do
      long_agent = "a" * 1000
      data[:user_agent] = long_agent

      BrowserPageView.log!(data)
      view = BrowserPageView.order(:created_at).last

      expect(view.user_agent.length).to eq(512)
    end

    it "truncates long referrer values" do
      long_referrer = "a" * 2000
      data[:referrer] = long_referrer

      BrowserPageView.log!(data)
      view = BrowserPageView.order(:created_at).last

      expect(view.referrer.length).to eq(1024)
    end

    it "handles nil values gracefully" do
      minimal_data = {
        status: 200,
        is_crawler: false,
        is_mobile: false,
        is_api: false,
        is_user_api: false,
      }

      expect { BrowserPageView.log!(minimal_data) }.to change { BrowserPageView.count }.by(1)

      view = BrowserPageView.order(:created_at).last
      expect(view.user_id).to be_nil
      expect(view.topic_id).to be_nil
      expect(view.path).to be_nil
      expect(view.query_string).to be_nil
      expect(view.route).to be_nil
    end

    it "handles errors gracefully" do
      allow(BrowserPageView).to receive(:create!).and_raise(StandardError.new("DB error"))

      expect { BrowserPageView.log!(data) }.not_to raise_error
    end
  end
end
