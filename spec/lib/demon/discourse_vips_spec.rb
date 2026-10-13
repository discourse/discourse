# frozen_string_literal: true

require "demon/discourse_vips"

RSpec.describe Demon::DiscourseVips do
  let(:directory) { Dir.mktmpdir }
  let(:socket_path) { File.join(directory, "socket") }
  let(:demon) { described_class.new(0, rails_root: "#{directory}/") }

  around do |example|
    shared_worker = DiscourseVips::Client.instance_variable_get(:@shared_worker)
    example.run
  ensure
    DiscourseVips::Client.instance_variable_set(:@shared_worker, shared_worker)
  end

  before do
    DiscourseVips::WorkerProcess.stubs(:shared_socket_path).returns(socket_path)
    described_class.set_demons("discourse_vips_0" => demon)
  end

  after do
    described_class.stop
    described_class.reset_demons
    FileUtils.remove_entry(directory)
  end

  describe ".start" do
    it "starts a worker that serves image processing requests" do
      described_class.start

      expect(DiscourseVips.version).to match(/\A\d+\.\d+\.\d+\z/)
      expect(File.read(demon.pid_file).to_i).to eq(demon.pid)
    end

    it "allows startup to be retried after a readiness failure" do
      socket_address = Addrinfo.unix(socket_path)
      allow(Addrinfo).to receive(:unix).with(socket_path).and_return(socket_address)
      allow(socket_address).to receive(:connect).and_raise(Errno::ECONNREFUSED)
      stub_const(DiscourseVips::Client, :SHARED_WORKER_RETRY_SECONDS, 0) do
        expect { described_class.start }.to raise_error(DiscourseVips::WorkerUnavailable)
      end
      allow(socket_address).to receive(:connect).and_call_original

      described_class.start

      expect(DiscourseVips.version).to match(/\A\d+\.\d+\.\d+\z/)
      expect(File.read(demon.pid_file).to_i).to eq(demon.pid)
    end
  end

  describe "#ensure_running" do
    it "restores image processing after a replacement readiness failure" do
      described_class.start
      previous_pid = demon.pid
      Process.kill("KILL", previous_pid)
      Process.waitpid(previous_pid)
      socket_address = Addrinfo.unix(socket_path)
      allow(Addrinfo).to receive(:unix).with(socket_path).and_return(socket_address)
      allow(socket_address).to receive(:connect).and_raise(Errno::ECONNREFUSED)
      stub_const(DiscourseVips::Client, :SHARED_WORKER_RETRY_SECONDS, 0) do
        expect { demon.ensure_running }.to raise_error(DiscourseVips::WorkerUnavailable)
      end
      allow(socket_address).to receive(:connect).and_call_original

      demon.ensure_running

      expect(DiscourseVips.version).to match(/\A\d+\.\d+\.\d+\z/)
      expect(File.read(demon.pid_file).to_i).to eq(demon.pid)
      expect(demon.pid).not_to eq(previous_pid)
    end
  end
end
