# frozen_string_literal: true

require "rails_helper"

describe Middleware::EnforceHostname do

  before do
    RailsMultisite::ConnectionManagement.stubs(:current_db_hostnames).returns(['primary.example.com', 'secondary.example.com'])
    RailsMultisite::ConnectionManagement.stubs(:current_hostname).returns('primary.example.com')
  end

  def check_returned_host(input_host)
    resolved_host = nil

    app = described_class.new(
      lambda do |env|
        resolved_host = env["HTTP_HOST"]
        [200, {}, ["ok"]]
      end
    )

    app.call({ "HTTP_HOST" => input_host })

    resolved_host
  end

  it "works for the primary domain" do
    expect(check_returned_host("primary.example.com")).to eq("primary.example.com")
  end

  it "works for the secondary domain" do
    expect(check_returned_host("secondary.example.com")).to eq("secondary.example.com")
  end

  it "returns primary domain otherwise" do
    expect(check_returned_host("other.example.com")).to eq("primary.example.com")
    expect(check_returned_host(nil)).to eq("primary.example.com")
  end
end
