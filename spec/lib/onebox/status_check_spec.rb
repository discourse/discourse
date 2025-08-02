# frozen_string_literal: true

RSpec.describe Onebox::StatusCheck do
  before do
    stub_request(:get, "http://www.amazon.com/200-url").to_return(status: 200)
    stub_request(:get, "http://www.amazon.com/201-url").to_return(status: 201)
    stub_request(:get, "http://www.amazon.com/401-url").to_return(status: 401)
    stub_request(:get, "http://www.amazon.com/403-url").to_return(status: 403)
    stub_request(:get, "http://www.amazon.com/404-url").to_return(status: 404)
    stub_request(:get, "http://www.amazon.com/500-url").to_return(status: 500)
    stub_request(:get, "http://www.amazon.com/503-url").to_return(status: 503)
    stub_request(:get, "http://www.amazon.com/timeout-url").to_raise(Timeout::Error)
    stub_request(:get, "http://www.amazon.com/http-error").to_raise(
      Net::HTTPError.new("error", nil),
    )
    stub_request(:get, "http://www.amazon.com/error-connecting").to_raise(Errno::ECONNREFUSED)
  end

  describe "#human_status" do
    it "returns :success on HTTP status code 200" do
      expect(described_class.new("http://www.amazon.com/200-url").human_status).to eq(:success)
    end

    it "returns :success on HTTP status code 201" do
      expect(described_class.new("http://www.amazon.com/201-url").human_status).to eq(:success)
    end

    it "returns :client_error on HTTP status code 401" do
      expect(described_class.new("http://www.amazon.com/401-url").human_status).to eq(:client_error)
    end

    it "returns :client_error on HTTP status code 403" do
      expect(described_class.new("http://www.amazon.com/403-url").human_status).to eq(:client_error)
    end

    it "returns :client_error on HTTP status code 404" do
      expect(described_class.new("http://www.amazon.com/404-url").human_status).to eq(:client_error)
    end

    it "returns :server_error on HTTP status code 500" do
      expect(described_class.new("http://www.amazon.com/500-url").human_status).to eq(:server_error)
    end

    it "returns :server_error on HTTP status code 503" do
      expect(described_class.new("http://www.amazon.com/503-url").human_status).to eq(:server_error)
    end

    it "returns :connection_error if there is a connection refused error" do
      expect(described_class.new("http://www.amazon.com/error-connecting").human_status).to eq(
        :connection_error,
      )
    end

    it "returns :connection_error if there is a timeout error" do
      expect(described_class.new("http://www.amazon.com/timeout-url").human_status).to eq(
        :connection_error,
      )
    end

    it "returns :connection_error if there is a general HTTP error" do
      expect(described_class.new("http://www.amazon.com/http-error").human_status).to eq(
        :connection_error,
      )
    end

    it "returns :connection_error for private ips" do
      FinalDestination::TestHelper.stub_to_fail do
        expect(described_class.new("http://www.amazon.com/http-error").human_status).to eq(
          :connection_error,
        )
      end
    end
  end

  describe "#ok?" do
    it "returns true for HTTP status codes 200-299" do
      expect(described_class.new("http://www.amazon.com/200-url").ok?).to be true
    end

    it "returns false for any status codes other than 200-299" do
      expect(described_class.new("http://www.amazon.com/404-url").ok?).to be false
    end
  end
end
