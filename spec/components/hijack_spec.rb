require 'rails_helper'

describe Hijack do
  class Hijack::Tester < ApplicationController
    attr_reader :io

    include Hijack

    def initialize(env = {})
      @io = StringIO.new

      env.merge!(
        "rack.hijack" => lambda { @io },
        "rack.input" => StringIO.new
      )

      self.request = ActionController::TestRequest.new(env, nil, nil)

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

  context "Request Tracker integration" do
    let :logger do
      lambda do |env, data|
        @calls += 1
        @status = data[:status]
        @total = data[:timing][:total_duration]
      end
    end

    before do
      Middleware::RequestTracker.register_detailed_request_logger logger
      @calls = 0
    end

    after do
      Middleware::RequestTracker.unregister_detailed_request_logger logger
    end

    it "can properly track execution" do
      app = lambda do |env|
        tester = Hijack::Tester.new(env)
        tester.hijack_test do
          render body: "hello", status: 201
        end
      end

      env = {}
      middleware = Middleware::RequestTracker.new(app)

      middleware.call(env)

      expect(@calls).to eq(1)
      expect(@status).to eq(201)
      expect(@status).to be > 0
    end
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

  it "handles cors" do
    SiteSetting.cors_origins = "www.rainbows.com"

    app = lambda do |env|
      tester = Hijack::Tester.new(env)
      tester.hijack_test do
        render body: "hello", status: 201
      end

      expect(tester.io.string).to include("Access-Control-Allow-Origin: www.rainbows.com")
    end

    env = {}
    middleware = Discourse::Cors.new(app)
    middleware.call(env)

    # it can do pre-flight
    env = {
      'REQUEST_METHOD' => 'OPTIONS',
      'HTTP_ACCESS_CONTROL_REQUEST_METHOD' => 'GET'
    }

    status, headers, _body = middleware.call(env)

    expect(status).to eq(200)

    expected = {
      "Access-Control-Allow-Origin" => "www.rainbows.com",
      "Access-Control-Allow-Headers" => "Content-Type, Cache-Control, X-Requested-With, X-CSRF-Token, Discourse-Visible, User-Api-Key, User-Api-Client-Id",
      "Access-Control-Allow-Credentials" => "true",
      "Access-Control-Allow-Methods" => "POST, PUT, GET, OPTIONS, DELETE"
    }

    expect(headers).to eq(expected)
  end

  it "handles transfers headers" do
    tester.response.headers["Hello-World"] = "sam"
    tester.hijack_test do
      expires_in 1.year
      render body: "hello world", status: 402
    end

    expect(tester.io.string).to include("Hello-World: sam")
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
    Process.stubs(:clock_gettime).returns(1.0)
    tester.hijack_test do
      Process.stubs(:clock_gettime).returns(2.0)
      redirect_to 'http://awesome.com'
    end

    result = "HTTP/1.1 302 Found\r\nLocation: http://awesome.com\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: 84\r\nConnection: close\r\nX-Runtime: 1.000000\r\n\r\n<html><body>You are being <a href=\"http://awesome.com\">redirected</a>.</body></html>"
    expect(tester.io.string).to eq(result)
  end

  it "renders stuff correctly if is empty" do
    Process.stubs(:clock_gettime).returns(1.0)
    tester.hijack_test do
      Process.stubs(:clock_gettime).returns(2.0)
      render body: nil
    end

    result = "HTTP/1.1 200 OK\r\nContent-Type: text/plain; charset=utf-8\r\nContent-Length: 0\r\nConnection: close\r\nX-Runtime: 1.000000\r\n\r\n"
    expect(tester.io.string).to eq(result)
  end

  it "renders stuff correctly if it works" do
    Process.stubs(:clock_gettime).returns(1.0)
    tester.hijack_test do
      Process.stubs(:clock_gettime).returns(2.0)
      render plain: "hello world"
    end

    result = "HTTP/1.1 200 OK\r\nContent-Type: text/plain; charset=utf-8\r\nContent-Length: 11\r\nConnection: close\r\nX-Runtime: 1.000000\r\n\r\nhello world"
    expect(tester.io.string).to eq(result)
  end

  it "returns 500 by default" do
    Process.stubs(:clock_gettime).returns(1.0)
    tester.hijack_test

    expected = "HTTP/1.1 500 Internal Server Error\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: 0\r\nConnection: close\r\nX-Runtime: 0.000000\r\n\r\n"
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
