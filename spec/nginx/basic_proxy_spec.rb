# frozen_string_literal: true

require "json"

RSpec.describe "nginx.sample.conf basic proxying" do # rubocop:disable RSpec/DescribeClass
  let(:harness) { Nginx::Support::NginxHarness.new }

  before { harness.start }
  after { harness.stop }

  it "forwards a GET / to the upstream and returns its response" do
    response = harness.get("/")

    expect(response.code).to eq("200")

    payload = JSON.parse(response.body)
    expect(payload["method"]).to eq("GET")
    expect(payload["path"]).to eq("/")
  end
end
