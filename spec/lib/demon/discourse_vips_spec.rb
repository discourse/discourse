# frozen_string_literal: true

require "demon/discourse_vips"

RSpec.describe Demon::DiscourseVips do
  describe ".start" do
    let(:directory) { Dir.mktmpdir }
    let(:socket_path) { File.join(directory, "socket") }
    let(:demon) { described_class.new(0, rails_root: "#{directory}/") }
    let(:previous_workers) { [] }

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
      previous_workers.each(&:shutdown)
      described_class.reset_demons
      FileUtils.remove_entry(directory)
    end

    it "starts a worker that serves image processing requests" do
      described_class.start

      expect(DiscourseVips.version).to match(/\A\d+\.\d+\.\d+\z/)
      expect(File.read(demon.pid_file).to_i).to eq(demon.pid)
    end

    it "restores image processing after an unresponsive previous worker" do
      previous = DiscourseVips::WorkerProcess.new(socket_path:)
      previous_workers << previous
      DiscourseVips::Client.use_shared_worker
      expect(DiscourseVips.version).to match(/\A\d+\.\d+\.\d+\z/)
      FileUtils.mkdir_p(File.dirname(demon.pid_file))
      File.write(demon.pid_file, previous.pid)
      Process.kill("STOP", previous.pid)
      described_class.start

      wait_for(timeout: 15) { demon.pid && File.read(demon.pid_file).to_i == demon.pid }
      expect(DiscourseVips.version).to match(/\A\d+\.\d+\.\d+\z/)
      expect(Demon::Base.running?(previous.pid)).to eq(false)
      expect(demon.pid).not_to eq(previous.pid)
    end
  end
end
