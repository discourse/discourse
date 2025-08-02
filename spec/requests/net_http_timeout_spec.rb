# frozen_string_literal: true

RSpec.describe "Net::HTTP timeouts when processing a request" do
  it "should set the right timeouts for any `Net::HTTP` instances intialized while processing a request" do
    stub_const(NetHTTPPatch, :OPEN_TIMEOUT, 0.001) do
      stub_const(NetHTTPPatch, :READ_TIMEOUT, 0.002) do
        stub_const(NetHTTPPatch, :WRITE_TIMEOUT, 0.003) do
          get "/test_net_http_timeouts.json"

          parsed = response.parsed_body

          expect(parsed["open_timeout"]).to eq(0.001)
          expect(parsed["read_timeout"]).to eq(0.002)
          expect(parsed["write_timeout"]).to eq(0.003)
          expect(parsed["max_retries"]).to eq(0)
        end
      end
    end
  end
end
