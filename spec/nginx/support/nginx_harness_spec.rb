# frozen_string_literal: true

require_relative "nginx_harness"

RSpec.describe Nginx::Support::NginxHarness do
  describe "#start" do
    it "binds the upstream before choosing the nginx listen port" do
      harness_class =
        Class.new(described_class) do
          attr_reader :events

          def initialize
            super(sample_path: "/tmp/unused-nginx-sample.conf")
            @events = []
            @next_port = 30_000
          end

          private

          def allocate_port
            @events << :allocate_port
            @next_port += 1
          end

          def start_upstream
            @events << :start_upstream
          end

          def render_and_spawn_nginx
            @events << :render_and_spawn_nginx
          end

          def wait_for_port(port, label, _timeout: 5)
            @events << [:wait_for_port, port, label]
            true
          end
        end
      harness = harness_class.new

      begin
        harness.start

        expect(harness.events).to eq(
          [
            :allocate_port,
            :start_upstream,
            :allocate_port,
            :render_and_spawn_nginx,
            [:wait_for_port, 30_002, "nginx"],
          ],
        )
      ensure
        harness.stop
      end
    end
  end

  describe "#request" do
    it "uses short HTTP open and read timeouts" do
      harness = described_class.new
      harness.instance_variable_set(:@listen_port, 30_000)
      http = instance_double(Net::HTTP)
      response = instance_double(Net::HTTPResponse)

      allow(Net::HTTP).to receive(:start) { |_host, _port, **_options, &block| block.call(http) }
      allow(http).to receive(:request).and_return(response)

      expect(harness.get("/")).to eq(response)
      expect(Net::HTTP).to have_received(:start).with(
        "127.0.0.1",
        30_000,
        open_timeout: described_class::HTTP_TIMEOUT_SECONDS,
        read_timeout: described_class::HTTP_TIMEOUT_SECONDS,
      )
      expect(http).to have_received(:request).with(instance_of(Net::HTTP::Get))
    end

    it "raises with nginx logs when a request times out" do
      harness_class =
        Class.new(described_class) do
          attr_reader :log_message

          private

          def raise_with_logs(message)
            @log_message = message
            raise "logs included"
          end
        end
      harness = harness_class.new
      harness.instance_variable_set(:@listen_port, 30_000)

      allow(Net::HTTP).to receive(:start).and_raise(Net::ReadTimeout)

      expect { harness.get("/slow") }.to raise_error(RuntimeError, "logs included")
      expect(harness.log_message).to include("GET /slow timed out")
      expect(harness.log_message).to include("Net::ReadTimeout")
    end
  end
end
