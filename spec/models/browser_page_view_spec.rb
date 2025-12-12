# frozen_string_literal: true

RSpec.describe BrowserPageView do
  describe ".log!" do
    let(:data) do
      {
        session_id: "abc12345-1234-1234-1234-123456789012",
        current_user_id: 1,
        topic_id: 123,
        path: "/t/test-topic/123",
        query_string: "page=2",
        route_name: "topic.fromParamsNear",
        user_agent: "Mozilla/5.0 Test Browser",
        request_remote_ip: "192.168.1.1",
        referrer: "https://google.com",
        is_mobile: true,
      }
    end

    it "creates a browser page view record" do
      expect { BrowserPageView.log!(data) }.to change { BrowserPageView.count }.by(1)

      log = BrowserPageView.order(:created_at).last
      expect(log.session_id).to eq("abc12345-1234-1234-1234-123456789012")
      expect(log.user_id).to eq(1)
      expect(log.topic_id).to eq(123)
      expect(log.path).to eq("/t/test-topic/123")
      expect(log.query_string).to eq("page=2")
      expect(log.route_name).to eq("topic.fromParamsNear")
      expect(log.user_agent).to eq("Mozilla/5.0 Test Browser")
      expect(log.ip_address.to_s).to eq("192.168.1.1")
      expect(log.referrer).to eq("https://google.com")
      expect(log.is_mobile).to eq(true)
      expect(log.created_at).to be_present
    end

    it "stores session_id correctly" do
      BrowserPageView.log!(data)
      log = BrowserPageView.order(:created_at).last
      expect(log.session_id).to be_present
    end

    it "truncates long session_id values" do
      data[:session_id] = "a" * 100
      BrowserPageView.log!(data)
      log = BrowserPageView.order(:created_at).last
      expect(log.session_id.length).to eq(36)
    end

    it "truncates long path values" do
      data[:path] = "a" * 2000
      BrowserPageView.log!(data)
      log = BrowserPageView.order(:created_at).last
      expect(log.path.length).to eq(1024)
    end

    it "truncates long query_string values" do
      data[:query_string] = "a" * 2000
      BrowserPageView.log!(data)
      log = BrowserPageView.order(:created_at).last
      expect(log.query_string.length).to eq(1024)
    end

    it "truncates long route_name values" do
      data[:route_name] = "a" * 500
      BrowserPageView.log!(data)
      log = BrowserPageView.order(:created_at).last
      expect(log.route_name.length).to eq(256)
    end

    it "truncates long referrer values" do
      data[:referrer] = "a" * 2000
      BrowserPageView.log!(data)
      log = BrowserPageView.order(:created_at).last
      expect(log.referrer.length).to eq(1024)
    end

    it "truncates long user_agent values" do
      data[:user_agent] = "a" * 1000
      BrowserPageView.log!(data)
      log = BrowserPageView.order(:created_at).last
      expect(log.user_agent.length).to eq(512)
    end

    it "handles nil values gracefully" do
      minimal_data = { is_mobile: false }

      expect { BrowserPageView.log!(minimal_data) }.to change { BrowserPageView.count }.by(1)

      log = BrowserPageView.order(:created_at).last
      expect(log.session_id).to be_nil
      expect(log.user_id).to be_nil
      expect(log.topic_id).to be_nil
      expect(log.path).to be_nil
      expect(log.query_string).to be_nil
      expect(log.route_name).to be_nil
    end

    it "handles errors gracefully" do
      allow(BrowserPageView).to receive(:create!).and_raise(StandardError.new("DB error"))

      expect { BrowserPageView.log!(data) }.not_to raise_error
    end
  end
end
