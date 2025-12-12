# frozen_string_literal: true

RSpec.describe ApiRequestLog do
  describe ".log!" do
    let(:data) do
      {
        current_user_id: 1,
        path: "/admin/users.json",
        route: "admin/users#index",
        http_method: "GET",
        status: 200,
        request_remote_ip: "192.168.1.1",
        user_agent: "API Client/1.0",
        is_user_api: false,
        timing: 0.123,
      }
    end

    it "creates an API request log record" do
      expect { ApiRequestLog.log!(data) }.to change { ApiRequestLog.count }.by(1)

      log = ApiRequestLog.order(:created_at).last
      expect(log.user_id).to eq(1)
      expect(log.path).to eq("/admin/users.json")
      expect(log.route).to eq("admin/users#index")
      expect(log.http_method).to eq("GET")
      expect(log.http_status).to eq(200)
      expect(log.ip_address.to_s).to eq("192.168.1.1")
      expect(log.user_agent).to eq("API Client/1.0")
      expect(log.is_user_api).to eq(false)
      expect(log.response_time).to eq(0.123)
      expect(log.created_at).to be_present
    end

    it "truncates long path values" do
      data[:path] = "a" * 2000
      ApiRequestLog.log!(data)
      log = ApiRequestLog.order(:created_at).last
      expect(log.path.length).to eq(1024)
    end

    it "truncates long route values" do
      data[:route] = "a" * 200
      ApiRequestLog.log!(data)
      log = ApiRequestLog.order(:created_at).last
      expect(log.route.length).to eq(100)
    end

    it "truncates long user_agent values" do
      data[:user_agent] = "a" * 1000
      ApiRequestLog.log!(data)
      log = ApiRequestLog.order(:created_at).last
      expect(log.user_agent.length).to eq(512)
    end

    it "captures HTTP method" do
      %w[GET POST PUT DELETE PATCH].each do |method|
        data[:http_method] = method
        ApiRequestLog.log!(data)
        log = ApiRequestLog.order(:created_at).last
        expect(log.http_method).to eq(method)
      end
    end

    it "captures response time" do
      data[:timing] = 1.5
      ApiRequestLog.log!(data)
      log = ApiRequestLog.order(:created_at).last
      expect(log.response_time).to eq(1.5)
    end

    it "handles nil values gracefully" do
      minimal_data = { status: 200, is_user_api: false }

      expect { ApiRequestLog.log!(minimal_data) }.to change { ApiRequestLog.count }.by(1)

      log = ApiRequestLog.order(:created_at).last
      expect(log.user_id).to be_nil
      expect(log.path).to be_nil
      expect(log.route).to be_nil
      expect(log.http_method).to be_nil
    end

    it "handles errors gracefully" do
      allow(ApiRequestLog).to receive(:create!).and_raise(StandardError.new("DB error"))

      expect { ApiRequestLog.log!(data) }.not_to raise_error
    end

    it "correctly identifies user API requests" do
      data[:is_user_api] = true
      ApiRequestLog.log!(data)
      log = ApiRequestLog.order(:created_at).last
      expect(log.is_user_api).to eq(true)
    end
  end
end
