require "spec_helper"

describe Onebox::StatusCheck do
  before do
    FakeWeb.register_uri(:get, "http://www.amazon.com/200-url", status: 200)
    FakeWeb.register_uri(:get, "http://www.amazon.com/201-url", status: 201)
    FakeWeb.register_uri(:get, "http://www.amazon.com/401-url", status: 401)
    FakeWeb.register_uri(:get, "http://www.amazon.com/403-url", status: 403)
    FakeWeb.register_uri(:get, "http://www.amazon.com/404-url", status: 404)
    FakeWeb.register_uri(:get, "http://www.amazon.com/500-url", status: 500)
    FakeWeb.register_uri(:get, "http://www.amazon.com/503-url", status: 503)
    FakeWeb.register_uri(:get, "http://www.amazon.com/timeout-url", exception: Timeout::Error)
    FakeWeb.register_uri(:get, "http://www.amazon.com/http-error", exception: Net::HTTPError)
    FakeWeb.register_uri(:get, "http://www.amazon.com/error-connecting", exception: Errno::ECONNREFUSED)
  end

  describe '#human_status' do
    it 'returns :success on HTTP status code 200' do
      expect(described_class.new("http://www.amazon.com/200-url").human_status).to eq(:success)
    end

    it 'returns :success on HTTP status code 201' do
      expect(described_class.new("http://www.amazon.com/201-url").human_status).to eq(:success)
    end

    it 'returns :client_error on HTTP status code 401' do
      expect(described_class.new("http://www.amazon.com/401-url").human_status).to eq(:client_error)
    end

    it 'returns :client_error on HTTP status code 403' do
      expect(described_class.new("http://www.amazon.com/403-url").human_status).to eq(:client_error)
    end

    it 'returns :client_error on HTTP status code 404' do
      expect(described_class.new("http://www.amazon.com/404-url").human_status).to eq(:client_error)
    end

    it 'returns :server_error on HTTP status code 500' do
      expect(described_class.new("http://www.amazon.com/500-url").human_status).to eq(:server_error)
    end

    it 'returns :server_error on HTTP status code 503' do
      expect(described_class.new("http://www.amazon.com/503-url").human_status).to eq(:server_error)
    end

    it 'returns :connection_error if there is a connection refused error' do
      expect(described_class.new("http://www.amazon.com/error-connecting").human_status).to eq(:connection_error)
    end

    it 'returns :connection_error if there is a timeout error' do
      expect(described_class.new("http://www.amazon.com/timeout-url").human_status).to eq(:connection_error)
    end

    it 'returns :connection_error if there is a general HTTP error' do
      expect(described_class.new("http://www.amazon.com/http-error").human_status).to eq(:connection_error)
    end
  end

  describe '#ok?' do
    it 'returns true for HTTP status codes 200-299' do
      expect(described_class.new("http://www.amazon.com/200-url").ok?).to be true
    end

    it 'returns false for any status codes other than 200-299' do
      expect(described_class.new("http://www.amazon.com/404-url").ok?).to be false
    end
  end
end
