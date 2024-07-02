# frozen_string_literal: true

RSpec.describe "Middleware order" do
  it "order of middleware in the application is correct" do
    middlewares = Rails.configuration.middleware.map { |middleware| "#{middleware.inspect}" }
    expect(middlewares).to eq(
      %w[
        BlockRequestsMiddleware
        TestMultisiteMiddleware
        ActionDispatch::RemoteIp
        Middleware::RequestTracker
        MessageBus::Rack::Middleware
        ActionDispatch::HostAuthorization
        Rack::Sendfile
        ActionDispatch::Static
        ActionDispatch::Executor
        Rack::MethodOverride
        Middleware::EnforceHostname
        ActionDispatch::RequestId
        SilenceLogger
        ActionDispatch::ShowExceptions
        ActionDispatch::DebugExceptions
        ActionDispatch::Callbacks
        ActionDispatch::Cookies
        ActionDispatch::Session::DiscourseCookieStore
        Discourse::Cors
        ActionDispatch::Flash
        RspecErrorTracker
        Middleware::CspScriptNonceInjector
        Middleware::AnonymousCache
        ContentSecurityPolicy::Middleware
        ActionDispatch::PermissionsPolicy::Middleware
        Rack::Head
        Rack::ConditionalGet
        Rack::TempfileReaper
        Middleware::OmniauthBypassMiddleware
      ],
    )
  end

  it "ensures that ActionDispatch::RemoteIp comes before Middleware::RequestTracker" do
    remote_ip_found = false
    request_tracker_found = false
    Rails.configuration.middleware.each do |middleware|
      remote_ip_found = true if middleware.inspect == "ActionDispatch::RemoteIp"
      expect(remote_ip_found).to eq(true) if middleware.inspect == "Middleware::RequestTracker"
    end
  end
end
