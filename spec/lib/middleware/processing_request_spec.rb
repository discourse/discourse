# frozen_string_literal: true

RSpec.describe Middleware::ProcessingRequest do
  let(:app) { described_class.new(lambda { |env| [200, {}, ["ok"]] }) }

  describe "#call" do
    it "sets the request queue seconds in the env based on the HTTP-X-REQUEST-START header" do
      env = create_request_env.merge("HTTP_X_REQUEST_START" => "t=#{(Time.now.to_f - 2)}")
      _status, _headers, _body = app.call(env)

      expect(env[described_class::REQUEST_QUEUE_SECONDS_ENV_KEY]).to be_within(0.1).of(2.0)
    end

    it "does not set the request queue seconds in the env if the HTTP-X-REQUEST-START header is missing" do
      env = create_request_env
      _status, _headers, _body = app.call(env)

      expect(env).not_to have_key(described_class::REQUEST_QUEUE_SECONDS_ENV_KEY)
    end
  end
end
