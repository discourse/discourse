# frozen_string_literal: true

RSpec.describe Hijack do
  class Hijack::Tester < ApplicationController
    attr_reader :io

    include Hijack
    include CurrentUser

    def initialize(env = {})
      @io = StringIO.new

      env.merge!("rack.hijack" => lambda { @io }, "rack.input" => StringIO.new)

      self.request = ActionController::TestRequest.new(env, nil, nil)

      # we need this for the 418
      set_response!(ActionDispatch::Response.new)
    end

    def hijack_test(&blk)
      hijack(&blk)
    end
  end

  let(:tester) { Hijack::Tester.new }

  describe "Request Tracker integration" do
    let(:logger) do
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

    after { Middleware::RequestTracker.unregister_detailed_request_logger logger }

    it "can properly track execution" do
      app =
        lambda do |env|
          tester = Hijack::Tester.new(env)
          tester.hijack_test { render body: "hello", status: 201 }
        end

      env = create_request_env(path: "/")
      middleware = Middleware::RequestTracker.new(app)

      middleware.call(env)

      expect(@calls).to eq(1)
      expect(@status).to eq(201)
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
    global_setting :enable_cors, true

    app =
      lambda do |env|
        tester = Hijack::Tester.new(env)
        tester.hijack_test { render body: "hello", status: 201 }

        expect(tester.io.string).to include("Access-Control-Allow-Origin: www.rainbows.com")
      end

    env = {}
    middleware = Discourse::Cors.new(app)
    middleware.call(env)

    # it can do pre-flight
    env = { "REQUEST_METHOD" => "OPTIONS", "HTTP_ACCESS_CONTROL_REQUEST_METHOD" => "GET" }

    status, headers, _body = middleware.call(env)

    expect(status).to eq(200)

    expected = {
      "Access-Control-Allow-Origin" => "www.rainbows.com",
      "Access-Control-Allow-Headers" =>
        "Content-Type, Cache-Control, X-Requested-With, X-CSRF-Token, Discourse-Present, User-Api-Key, User-Api-Client-Id, Authorization",
      "Access-Control-Allow-Credentials" => "true",
      "Access-Control-Allow-Methods" => "POST, PUT, GET, OPTIONS, DELETE",
      "Access-Control-Max-Age" => "7200",
    }

    expect(headers).to eq(expected)
  end

  it "removes trailing slash in cors origin" do
    GlobalSetting.stubs(:enable_cors).returns(true)
    GlobalSetting.stubs(:cors_origin).returns("https://www.rainbows.com/")

    app =
      lambda do |env|
        tester = Hijack::Tester.new(env)
        tester.hijack_test { render body: "hello", status: 201 }

        expect(tester.io.string).to include("Access-Control-Allow-Origin: https://www.rainbows.com")
      end

    env = {}
    middleware = Discourse::Cors.new(app)
    middleware.call(env)

    # it can do pre-flight
    env = { "REQUEST_METHOD" => "OPTIONS", "HTTP_ACCESS_CONTROL_REQUEST_METHOD" => "GET" }

    status, headers, _body = middleware.call(env)

    expect(status).to eq(200)

    expected = {
      "Access-Control-Allow-Origin" => "https://www.rainbows.com",
      "Access-Control-Allow-Headers" =>
        "Content-Type, Cache-Control, X-Requested-With, X-CSRF-Token, Discourse-Present, User-Api-Key, User-Api-Client-Id, Authorization",
      "Access-Control-Allow-Credentials" => "true",
      "Access-Control-Allow-Methods" => "POST, PUT, GET, OPTIONS, DELETE",
      "Access-Control-Max-Age" => "7200",
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
    tester.hijack_test { render body: "hello world", status: 402 }

    expect(tester.io.string).to include("402")
    expect(tester.io.string).to include("world")
  end

  it "handles send_file correctly" do
    tester.hijack_test { send_file __FILE__, disposition: nil }

    expect(tester.io.string).to start_with("HTTP/1.1 200")
  end

  it "renders a redirect correctly" do
    Process.stubs(:clock_gettime).returns(1.0)
    tester.hijack_test do
      Process.stubs(:clock_gettime).returns(2.0)
      redirect_to "http://awesome.com", allow_other_host: true
    end

    result =
      "HTTP/1.1 302 Found\r\nLocation: http://awesome.com\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: 0\r\nConnection: close\r\nX-Runtime: 1.000000\r\n\r\n"
    expect(tester.io.string).to eq(result)
  end

  it "renders stuff correctly if is empty" do
    Process.stubs(:clock_gettime).returns(1.0)
    tester.hijack_test do
      Process.stubs(:clock_gettime).returns(2.0)
      render body: nil
    end

    result =
      "HTTP/1.1 200 OK\r\nContent-Type: text/plain; charset=utf-8\r\nContent-Length: 0\r\nConnection: close\r\nX-Runtime: 1.000000\r\n\r\n"
    expect(tester.io.string).to eq(result)
  end

  it "renders stuff correctly if it works" do
    Process.stubs(:clock_gettime).returns(1.0)
    tester.hijack_test do
      Process.stubs(:clock_gettime).returns(2.0)
      render plain: "hello world"
    end

    result =
      "HTTP/1.1 200 OK\r\nContent-Type: text/plain; charset=utf-8\r\nContent-Length: 11\r\nConnection: close\r\nX-Runtime: 1.000000\r\n\r\nhello world"
    expect(tester.io.string).to eq(result)
  end

  it "returns 500 by default" do
    Process.stubs(:clock_gettime).returns(1.0)
    tester.hijack_test

    expected =
      "HTTP/1.1 500 Internal Server Error\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: 0\r\nConnection: close\r\nX-Runtime: 0.000000\r\n\r\n"
    expect(tester.io.string).to eq(expected)
  end

  it "does not run the block if io is closed" do
    tester.io.close

    ran = false
    tester.hijack_test { ran = true }

    expect(ran).to eq(false)
  end

  it "handles the queue being full" do
    Scheduler::Defer.stubs(:later).raises(WorkQueue::WorkQueueFull.new)

    tester.hijack_test {}

    expect(tester.response.status).to eq(503)
  end

  context "when there is a current user" do
    fab!(:test_current_user) { Fabricate(:user) }

    it "captures the current user" do
      test_user_id = nil

      tester =
        Hijack::Tester.new(Auth::DefaultCurrentUserProvider::CURRENT_USER_KEY => test_current_user)

      tester.hijack_test { test_user_id = current_user.id }

      expect(test_user_id).to eq(test_current_user.id)
    end

    it "uses the current user's locale for translations" do
      SiteSetting.allow_user_locale = true
      test_current_user.update!(locale: "es")
      test_translation = nil

      tester =
        Hijack::Tester.new(Auth::DefaultCurrentUserProvider::CURRENT_USER_KEY => test_current_user)

      # Simulates the around_action that sets the locale in ApplicationController, since this is
      # not a request spec.
      tester.with_resolved_locale { tester.hijack_test { test_translation = I18n.t("topics") } }

      expect(test_translation).to eq(I18n.t("topics", locale: "es"))
    end
  end
end
