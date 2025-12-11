# frozen_string_literal: true

RSpec.describe WebRequestLog do
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

    it "creates a web request log record" do
      expect { WebRequestLog.log!(data) }.to change { WebRequestLog.count }.by(1)

      log = WebRequestLog.order(:created_at).last
      expect(log.user_id).to eq(1)
      expect(log.topic_id).to eq(123)
      expect(log.path).to eq("/t/test-topic/123")
      expect(log.query_string).to eq("page=2")
      expect(log.route).to eq("topics#show")
      expect(log.user_agent).to eq("Mozilla/5.0 Test Browser")
      expect(log.ip_address.to_s).to eq("192.168.1.1")
      expect(log.referrer).to eq("https://google.com")
      expect(log.is_crawler).to eq(false)
      expect(log.is_mobile).to eq(true)
      expect(log.is_api).to eq(false)
      expect(log.is_user_api).to eq(false)
      expect(log.http_status).to eq(200)
      expect(log.created_at).to be_present
    end

    it "truncates long path values" do
      long_path = "a" * 2000
      data[:path] = long_path

      WebRequestLog.log!(data)
      log = WebRequestLog.order(:created_at).last

      expect(log.path.length).to eq(1024)
    end

    it "truncates long query_string values" do
      long_query = "a" * 2000
      data[:query_string] = long_query

      WebRequestLog.log!(data)
      log = WebRequestLog.order(:created_at).last

      expect(log.query_string.length).to eq(1024)
    end

    it "truncates long user_agent values" do
      long_agent = "a" * 1000
      data[:user_agent] = long_agent

      WebRequestLog.log!(data)
      log = WebRequestLog.order(:created_at).last

      expect(log.user_agent.length).to eq(512)
    end

    it "truncates long referrer values" do
      long_referrer = "a" * 2000
      data[:referrer] = long_referrer

      WebRequestLog.log!(data)
      log = WebRequestLog.order(:created_at).last

      expect(log.referrer.length).to eq(1024)
    end

    it "handles nil values gracefully" do
      minimal_data = {
        status: 200,
        is_crawler: false,
        is_mobile: false,
        is_api: false,
        is_user_api: false,
      }

      expect { WebRequestLog.log!(minimal_data) }.to change { WebRequestLog.count }.by(1)

      log = WebRequestLog.order(:created_at).last
      expect(log.user_id).to be_nil
      expect(log.topic_id).to be_nil
      expect(log.path).to be_nil
      expect(log.query_string).to be_nil
      expect(log.route).to be_nil
    end

    it "handles errors gracefully" do
      allow(WebRequestLog).to receive(:create!).and_raise(StandardError.new("DB error"))

      expect { WebRequestLog.log!(data) }.not_to raise_error
    end
  end
end
