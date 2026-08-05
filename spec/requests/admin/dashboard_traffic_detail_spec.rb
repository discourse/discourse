# frozen_string_literal: true

require "lograge"

RSpec.describe Admin::DashboardController do
  fab!(:admin)
  fab!(:other_admin, :admin)

  describe "#traffic" do
    let(:request_body) do
      { start_date: 2.days.ago.to_date.iso8601, end_date: Date.current.iso8601, filters: {} }
    end

    let(:result) do
      {
        analysis: {
        },
        filters: {
        },
        summary: {
          pageviews: 1,
        },
        series: [],
        dimensions: {
          top_urls: [],
          entry_urls: [],
          traffic_sources: [],
          countries: [],
          networks: [],
          browsers: [],
          ip_addresses: [],
        },
      }
    end

    def cache_result_for(body, actor: admin)
      request = AdminDashboardSiteTrafficDetail::Request.parse(body)
      key = AdminDashboardSiteTrafficDetail.cache_key(request: request, actor: actor)
      Discourse.cache.write(key, result, expires_in: 1.minute)
      key
    end

    before do
      SiteSetting.dashboard_improvements = true
      Discourse.cache.clear
      sign_in(admin)
    end

    it "returns invalid_request for malformed JSON without changing global parameter filters" do
      original_filters = Rails.application.config.filter_parameters.dup
      raw_payload = '{"filters":{"ip":"192.0.2.1\\nFORGED: yes\\r\\ntoken=secret"}'
      lograge_event = nil
      lograge_sink = Object.new
      lograge_sink.define_singleton_method(:process_action) { |event| lograge_event = event }
      previous_lograge = Rails.configuration.try(:lograge)
      Rails.configuration.lograge = ActiveSupport::OrderedOptions.new
      Rails.configuration.lograge.enabled = true
      Lograge::LogSubscribers::ActionController.stubs(:new).returns(lograge_sink)

      post "/admin/dashboard/traffic.json",
           params: raw_payload,
           headers: {
             "CONTENT_TYPE" => "application/json",
           }

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body).to eq("error_type" => "invalid_request")
      expect(response.body).not_to include("192.0.2.1", "FORGED", "token=secret", raw_payload)
      expect(lograge_event).to be_nil
      expect(Rails.application.config.filter_parameters).to eq(original_filters)
    ensure
      Rails.configuration.lograge = previous_lograge
    end

    it "reloads the actor and rejects a deleted admin before reading a cached response" do
      cache_result_for(request_body)
      AdminDashboardSiteTrafficDetail.expects(:new).never
      User.stubs(:find_by).with(id: admin.id).returns(admin, nil)

      post "/admin/dashboard/traffic.json", params: request_body, as: :json

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body).not_to eq(result.deep_stringify_keys)
    end

    it "rejects an admin demoted after the outer gate before reading a cached response" do
      cache_result_for(request_body)
      demoted_actor = admin.dup
      demoted_actor.id = admin.id
      demoted_actor.admin = false
      AdminDashboardSiteTrafficDetail.expects(:new).never
      User.stubs(:find_by).with(id: admin.id).returns(admin, demoted_actor)

      post "/admin/dashboard/traffic.json", params: request_body, as: :json

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body).not_to eq(result.deep_stringify_keys)
    end

    it "rejects an inactive admin reloaded after the outer gate" do
      cache_result_for(request_body)
      inactive_actor = admin.dup
      inactive_actor.id = admin.id
      inactive_actor.active = false
      AdminDashboardSiteTrafficDetail.expects(:new).never
      User.stubs(:find_by).with(id: admin.id).returns(admin, inactive_actor)

      post "/admin/dashboard/traffic.json", params: request_body, as: :json

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body).not_to eq(result.deep_stringify_keys)
    end

    it "rejects a suspended admin reloaded after the outer gate" do
      cache_result_for(request_body)
      suspended_actor = admin.dup
      suspended_actor.id = admin.id
      suspended_actor.suspended_till = 1.day.from_now
      AdminDashboardSiteTrafficDetail.expects(:new).never
      User.stubs(:find_by).with(id: admin.id).returns(admin, suspended_actor)

      post "/admin/dashboard/traffic.json", params: request_body, as: :json

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body).not_to eq(result.deep_stringify_keys)
    end

    it "rebuilds Guardian and rejects its policy before reading a cached response" do
      cache_result_for(request_body)
      inner_actor = admin.dup
      inner_actor.id = admin.id
      inner_guardian = Guardian.new(inner_actor)
      inner_guardian.stubs(:is_admin?).returns(false)
      inner_actor.stubs(:guardian).returns(inner_guardian)
      AdminDashboardSiteTrafficDetail.expects(:new).never
      User.stubs(:find_by).with(id: admin.id).returns(admin, inner_actor)

      post "/admin/dashboard/traffic.json", params: request_body, as: :json

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body).not_to eq(result.deep_stringify_keys)
    end

    it "rechecks rollout eligibility after the outer gate before reading a cached response" do
      cache_result_for(request_body)
      AdminDashboardSiteTrafficDetail.expects(:new).never
      User.stubs(:find_by).with(id: admin.id).returns(admin, admin)
      UpcomingChanges
        .expects(:enabled_for_user?)
        .with(:dashboard_improvements, admin)
        .twice
        .returns(true, false)

      post "/admin/dashboard/traffic.json", params: request_body, as: :json

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body).not_to eq(result.deep_stringify_keys)
    end

    it "caches a successful response and makes the cache hit free of analytics work" do
      service = stub
      service.stubs(:call).returns(result)
      AdminDashboardSiteTrafficDetail.stubs(:new).returns(service)

      post "/admin/dashboard/traffic.json", params: request_body, as: :json
      first_response = response.parsed_body
      AdminDashboardSiteTrafficDetail.expects(:new).never

      post "/admin/dashboard/traffic.json", params: request_body, as: :json

      expect(response.parsed_body).to eq(first_response)
    end

    it "does not cache timeout failures and returns the retryable shape" do
      service = stub
      service.stubs(:call).raises(AdminDashboardSiteTrafficDetail::Timeout)
      AdminDashboardSiteTrafficDetail.stubs(:new).returns(service)

      post "/admin/dashboard/traffic.json", params: request_body, as: :json

      expect(response).to have_http_status(:service_unavailable)
      expect(response.parsed_body).to eq("error_type" => "timeout", "retryable" => true)
      expect(
        Discourse.cache.read(
          AdminDashboardSiteTrafficDetail.cache_key(
            request: AdminDashboardSiteTrafficDetail::Request.parse(request_body),
            actor: admin,
          ),
        ),
      ).to be_nil
    end

    it "returns a sanitized retryable response and does not cache unexpected failures" do
      sensitive_values = %w[
        192.0.2.123
        /top
        token=secret-value
        https://referrer.example/private
        FORGED
      ]
      error = StandardError.new(sensitive_values.join("\n"))
      service = stub
      service.stubs(:call).raises(error)
      AdminDashboardSiteTrafficDetail.stubs(:new).returns(service)
      warning = nil
      Discourse
        .expects(:warn_exception)
        .with do |warned_error, message:|
          warning = [warned_error.message, message]
          true
        end

      body =
        request_body.merge(
          filters: {
            ip: "192.0.2.123",
            top_url: "/top",
            entry_url: "/privacy",
            referrer: "referrer.example",
          },
        )
      key =
        AdminDashboardSiteTrafficDetail.cache_key(
          request: AdminDashboardSiteTrafficDetail::Request.parse(body),
          actor: admin,
        )

      post "/admin/dashboard/traffic.json", params: body, as: :json

      expect(response).to have_http_status(:internal_server_error)
      expect(response.parsed_body).to eq("error_type" => "unexpected", "retryable" => true)
      expect(warning).to eq(
        ["Site traffic detail request failed", "Failed to build Site traffic detail"],
      )
      sensitive_values.each do |value|
        expect(response.body).not_to include(value)
        expect(warning.join).not_to include(value)
      end
      expect(Discourse.cache.read(key)).to be_nil
    end

    it "rejects a sensitive URL filter without echoing it" do
      sensitive_url = "/internal/account"

      post "/admin/dashboard/traffic.json",
           params: request_body.merge(filters: { top_url: sensitive_url }),
           as: :json

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body).to eq("error_type" => "invalid_request")
      expect(response.body).not_to include(sensitive_url)
    end

    it "uses actor-specific cache keys" do
      request = AdminDashboardSiteTrafficDetail::Request.parse(request_body)

      expect(AdminDashboardSiteTrafficDetail.cache_key(request: request, actor: admin)).not_to eq(
        AdminDashboardSiteTrafficDetail.cache_key(request: request, actor: other_admin),
      )
    end

    it "accepts the canonical direct referrer value" do
      body = request_body.merge(filters: { referrer: "direct" })
      cache_result_for(body)

      post "/admin/dashboard/traffic.json", params: body, as: :json

      expect(response).to have_http_status(:ok)
    end

    it "filters the complete sensitive filters object for this request" do
      post "/admin/dashboard/traffic.json",
           params: request_body.merge(filters: { ip: "192.0.2.1\nsecret" }),
           as: :json

      expect(response).to have_http_status(:bad_request)
      expect(response.request.filtered_parameters["filters"]).to eq("[FILTERED]")
    end

    it "redacts request filters from hijacked Lograge and request-tracker output" do
      body =
        request_body.merge(
          filters: {
            ip: "192.0.2.123",
            top_url: "/top",
            entry_url: "/privacy",
            referrer: "referrer.example",
          },
        )
      service = stub
      service.stubs(:call).returns(result)
      AdminDashboardSiteTrafficDetail.stubs(:new).returns(service)
      lograge_event = nil
      lograge_sink = Object.new
      lograge_sink.define_singleton_method(:process_action) { |event| lograge_event = event }
      previous_lograge = Rails.configuration.try(:lograge)
      Rails.configuration.lograge = ActiveSupport::OrderedOptions.new
      Rails.configuration.lograge.enabled = true
      Lograge::LogSubscribers::ActionController.stubs(:new).returns(lograge_sink)
      request_tracker_data = []
      request_tracker_logger = ->(_env, data) { request_tracker_data << data }
      Middleware::RequestTracker.register_detailed_request_logger(request_tracker_logger)
      hijacked_io = StringIO.new

      post "/admin/dashboard/traffic.json",
           params: body,
           headers: {
             "rack.hijack" => -> { hijacked_io },
           },
           as: :json

      expect(response).to have_http_status(418)
      expect(hijacked_io.string).to include("HTTP/1.1 200 OK", result.to_json)
      expect(lograge_event.payload[:params]["filters"]).to eq("[FILTERED]")
      expect(lograge_event.payload[:params].dig("dashboard", "filters")).to eq("[FILTERED]")
      expect(lograge_event.payload[:path]).to eq("/admin/dashboard/traffic.json")

      serialized_lograge_payload = lograge_event.payload.except(:headers).to_json
      serialized_request_tracker_data = request_tracker_data.to_json
      [serialized_lograge_payload, serialized_request_tracker_data].each do |serialized_output|
        expect(serialized_output).not_to include(*body[:filters].values, body.to_json, "rack.input")
      end
    ensure
      if request_tracker_logger
        Middleware::RequestTracker.unregister_detailed_request_logger(request_tracker_logger)
      end
      Rails.configuration.lograge = previous_lograge
    end

    it "rejects an authenticated POST without a CSRF token when forgery protection is enabled" do
      ActionController::Base.allow_forgery_protection = true

      post "/admin/dashboard/traffic.json", params: request_body, as: :json

      expect(response).to have_http_status(:forbidden)
    ensure
      ActionController::Base.allow_forgery_protection = false
    end

    it "accepts an authenticated POST with a valid CSRF token" do
      ActionController::Base.allow_forgery_protection = true
      service = stub
      service.stubs(:call).returns(result)
      AdminDashboardSiteTrafficDetail.stubs(:new).returns(service)
      get "/session/csrf.json"
      csrf_token = response.parsed_body["csrf"]

      post "/admin/dashboard/traffic.json",
           params: request_body,
           headers: {
             "X-CSRF-Token" => csrf_token,
           },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq(result.deep_stringify_keys)
    ensure
      ActionController::Base.allow_forgery_protection = false
    end
  end
end
