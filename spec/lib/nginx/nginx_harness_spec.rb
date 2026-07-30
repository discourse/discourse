# frozen_string_literal: true

require_relative "../../nginx/support/nginx_harness"
require_relative "../../nginx/support/rails_upstream"

RSpec.describe Nginx::Support::NginxHarness do
  let(:upstream) do
    instance_double(Nginx::Support::RailsUpstream, start: nil, stop: nil, port: 30_001)
  end

  describe "#start" do
    it "starts the upstream before choosing the nginx listen port" do
      harness_class =
        Class.new(described_class) do
          attr_reader :events

          def initialize(upstream, events)
            super(upstream:, sample_path: "/tmp/unused-nginx-sample.conf")
            @events = events
            @next_port = 30_000
          end

          private

          def allocate_port
            @events << :allocate_port
            @next_port += 1
          end

          def render_and_spawn_nginx
            @events << :render_and_spawn_nginx
          end

          def wait_for_port(port, label, timeout: 5)
            @events << [:wait_for_port, port, label]
            true
          end
        end
      events = []
      allow(upstream).to receive(:start) { events << :start_upstream }
      allow(upstream).to receive(:port) do
        events << :read_upstream_port
        30_001
      end
      harness = harness_class.new(upstream, events)

      begin
        harness.start

        expect(harness.events).to eq(
          [
            :start_upstream,
            :read_upstream_port,
            :allocate_port,
            :render_and_spawn_nginx,
            [:wait_for_port, 30_001, "nginx"],
          ],
        )
      ensure
        harness.stop
      end
    end

    it "cleans up when nginx fails to start" do
      harness_class =
        Class.new(described_class) do
          private

          def render_and_spawn_nginx
            raise "nginx failed"
          end
        end
      harness = harness_class.new(upstream:)

      expect { harness.start }.to raise_error("nginx failed")
      expect(upstream).to have_received(:stop).once
      expect(harness.tmpdir).to be_nil

      harness.stop

      expect(upstream).to have_received(:stop).once
    end
  end

  describe "#nginx_access_log" do
    it "returns an empty log before start creates a tmpdir" do
      expect(described_class.new(upstream:).nginx_access_log).to eq("")
    end
  end

  describe "#request" do
    it "uses short HTTP open and read timeouts" do
      harness = described_class.new(upstream:)
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
      expect(http).to have_received(:request) do |request|
        expect(request).to be_a(Net::HTTP::Get)
      end
    end

    it "raises with nginx logs when a request times out" do
      Dir.mktmpdir do |tmpdir|
        harness = described_class.new(upstream:)
        harness.instance_variable_set(:@listen_port, 30_000)
        harness.instance_variable_set(:@tmpdir, tmpdir)
        File.write(File.join(tmpdir, "nginx-stderr.log"), "nginx stderr\n")

        allow(Net::HTTP).to receive(:start).and_raise(Net::ReadTimeout)

        expect { harness.get("/slow") }.to raise_error(RuntimeError) do |error|
          expect(error.message).to include("GET /slow timed out")
          expect(error.message).to include("Net::ReadTimeout")
          expect(error.message).to include("--- nginx-stderr.log ---\nnginx stderr")
        end
      end
    end
  end
end
