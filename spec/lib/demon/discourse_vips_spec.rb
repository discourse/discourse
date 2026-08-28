# frozen_string_literal: true

RSpec.describe Demon::DiscourseVips do
  describe ".start" do
    it "serves image operations from the supervised worker" do
      with_supervised_worker do
        described_class.start

        expect(DiscourseVips.version).to match(/\A\d+\.\d+\.\d+\z/)
      end
    end
  end

  describe ".ensure_running" do
    it "restarts the supervised worker after it exits" do
      with_supervised_worker do
        described_class.start
        worker_pid = described_class.demons.fetch("discourse_vips_0").pid
        Process.kill("KILL", worker_pid)
        Process.waitpid(worker_pid)

        described_class.ensure_running

        expect(DiscourseVips.version).to match(/\A\d+\.\d+\.\d+\z/)
      end
    end
  end

  def with_supervised_worker
    environment_key = DiscourseVips::WorkerProcess::SOCKET_PATH_ENV
    original_socket_path = ENV[environment_key]

    Dir.mktmpdir do |directory|
      ENV[environment_key] = File.join(directory, "worker", "socket")
      described_class.reset_demons
      yield
    ensure
      described_class.stop
      described_class.reset_demons
    end
  ensure
    original_socket_path ? ENV[environment_key] = original_socket_path : ENV.delete(environment_key)
    DiscourseVips.before_fork
  end
end
