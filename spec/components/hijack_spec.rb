require 'rails_helper'

describe Hijack do
  class Hijack::Tester < ApplicationController
    attr_reader :io

    include Hijack

    def initialize
      @io = StringIO.new
      self.request = ActionController::TestRequest.new({
        "rack.hijack" => lambda { @io },
        "rack.input" => StringIO.new
      },
        nil,
        nil
      )
      # we need this for the 418
      self.response = ActionDispatch::Response.new
    end

    def hijack_test(&blk)
      hijack(&blk)
    end

  end

  let :tester do
    Hijack::Tester.new
  end

  it "dupes the request params and env" do
    orig_req = tester.request
    copy_req = nil

    tester.hijack_test do
      copy_req = request
      render body: "hello world", status: 200
    end

    expect(copy_req.object_id).not_to eq(orig_req.object_id)
  end

  it "handles expires_in" do
    tester.hijack_test do
      expires_in 1.year
      render body: "hello world", status: 402
    end

    expect(tester.io.string).to include("max-age=31556952")
  end

  it "renders non 200 status if asked for" do
    tester.hijack_test do
      render body: "hello world", status: 402
    end

    expect(tester.io.string).to include("402")
    expect(tester.io.string).to include("world")
  end

  it "handles send_file correctly" do
    tester.hijack_test do
      send_file __FILE__, disposition: nil
    end

    expect(tester.io.string).to start_with("HTTP/1.1 200")
  end

  it "renders a redirect correctly" do
    tester.hijack_test do
      redirect_to 'http://awesome.com'
    end

    result = "HTTP/1.1 302 Found\r\nLocation: http://awesome.com\r\nContent-Type: text/html\r\nContent-Length: 84\r\nConnection: close\r\n\r\n<html><body>You are being <a href=\"http://awesome.com\">redirected</a>.</body></html>"
    expect(tester.io.string).to eq(result)
  end

  it "renders stuff correctly if is empty" do
    tester.hijack_test do
      render body: nil
    end

    result = "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
    expect(tester.io.string).to eq(result)
  end

  it "renders stuff correctly if it works" do
    tester.hijack_test do
      render plain: "hello world"
    end

    result = "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 11\r\nConnection: close\r\n\r\nhello world"
    expect(tester.io.string).to eq(result)
  end

  it "returns 500 by default" do
    tester.hijack_test

    expected = "HTTP/1.1 500 Internal Server Error\r\nContent-Type: text/html\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
    expect(tester.io.string).to eq(expected)
  end

  it "does not run the block if io is closed" do
    tester.io.close

    ran = false
    tester.hijack_test do
      ran = true
    end

    expect(ran).to eq(false)
  end
end
