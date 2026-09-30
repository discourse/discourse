# frozen_string_literal: true

RSpec.describe Middleware::ProcessingRequest do
  let(:app) { described_class.new(lambda { |env| [200, {}, ["ok"]] }) }

  describe "#call" do
    it "resumes background work before the request uses a thread pool" do
      pool = Scheduler::ThreadPool.new(min_threads: 0, max_threads: 1)
      result = Queue.new
      Scheduler::ThreadPool.pause
      middleware =
        described_class.new(
          lambda do |_env|
            pool.post { result << :completed }
            [200, {}, [result.pop(timeout: 5).to_s]]
          end,
        )

      expect(middleware.call(create_request_env)).to eq([200, {}, ["completed"]])
    ensure
      Scheduler::ThreadPool.resume
      pool&.shutdown
      pool&.wait_for_termination(timeout: 5)
    end

    it "sets the request queue seconds in the env based on the HTTP-X-REQUEST-START header" do
      env = create_request_env.merge("HTTP_X_REQUEST_START" => "t=#{Time.now.to_f - 2}")
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
