# frozen_string_literal: true

RSpec.describe "Middleware order" do
  let(:expected_middlewares) do
    [
      BlockRequestsMiddleware,
      TestMultisiteMiddleware,
      ActionDispatch::RemoteIp,
      Middleware::RequestTracker,
      MessageBus::Rack::Middleware,
      Middleware::ProcessingRequest,
      Rack::Sendfile,
      ActionDispatch::Static,
      ActionDispatch::Executor,
      Rack::MethodOverride,
      Middleware::EnforceHostname,
      ActionDispatch::RequestId,
      SilenceLogger,
      Middleware::DefaultHeaders,
      ActionDispatch::ShowExceptions,
      ActionDispatch::DebugExceptions,
      ActionDispatch::Callbacks,
      ActionDispatch::Cookies,
      ActionDispatch::Session::DiscourseCookieStore,
      Discourse::Cors,
      ActionDispatch::Flash,
      RspecErrorTracker,
      Middleware::CspScriptNonceInjector,
      Middleware::AnonymousCache,
      ContentSecurityPolicy::Middleware,
      ActionDispatch::PermissionsPolicy::Middleware,
      Rack::Head,
      Rack::ConditionalGet,
      Rack::TempfileReaper,
      Middleware::OmniauthBypassMiddleware,
    ]
  end
  let(:actual_middlewares) { Rails.configuration.middleware.middlewares }
  let(:remote_ip_index) { actual_middlewares.index(ActionDispatch::RemoteIp) }
  let(:request_tracker_index) { actual_middlewares.index(Middleware::RequestTracker) }

  it "has the correct order of middlewares" do
    expect(actual_middlewares).to eq(expected_middlewares)
  end

  it "ensures that ActionDispatch::RemoteIp comes before Middleware::RequestTracker" do
    expect(remote_ip_index).to be < request_tracker_index
  end

  it "ensures that Middleware::DefaultHeaders comes before ActionDispatch::ShowExceptions" do
    default_headers_index = actual_middlewares.index(Middleware::DefaultHeaders)
    show_exceptions_index = actual_middlewares.index(ActionDispatch::ShowExceptions)
    expect(default_headers_index).to be < show_exceptions_index
  end
end
