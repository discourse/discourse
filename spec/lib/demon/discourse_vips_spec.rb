# frozen_string_literal: true

RSpec.describe Demon::DiscourseVips do
  describe "#run" do
    it "does not start the broker when the pid file cannot be written" do
      daemon = described_class.new(0)
      socket_path = Rails.root.join("tmp", "discourse-vips-gated-#{Process.pid}.sock").to_s

      Discourse.stubs(:before_fork)
      DiscourseVips.stubs(socket_path:)
      daemon.stubs(:write_pid_file).raises("cannot write pid file")

      expect { daemon.run }.to raise_error("cannot write pid file")
      Process.wait(daemon.pid)

      expect(File.socket?(socket_path)).to eq(false)
    ensure
      FileUtils.rm_f(socket_path) if socket_path
    end

    it "executes a standalone broker that serves requests and shuts down cleanly" do
      Dir.mktmpdir do |temporary_directory|
        socket_path = File.join(temporary_directory, "discourse-vips.sock")
        daemon = described_class.new("spec-#{Process.pid}")

        DiscourseVips.stubs(socket_path:)
        daemon.run

        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
        loop do
          begin
            break if DiscourseVips.version(expected_broker_pid: daemon.pid)
          rescue DiscourseVips::Error
          end
          if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
            raise "DiscourseVips broker did not start"
          end

          sleep 0.01
        end

        pid_file = daemon.pid_file
        expect(File.read(pid_file).to_i).to eq(daemon.pid)

        daemon.stop
        daemon = nil

        expect([File.exist?(pid_file), File.exist?(socket_path)]).to eq([false, false])
      ensure
        daemon&.stop
      end
    end

    context "when the standalone broker fails during boot" do
      def prepare_failing_broker_root(temporary_directory:, broker_contents: nil)
        rails_root = Pathname(temporary_directory)
        FileUtils.mkdir_p(rails_root.join("lib/discourse_vips"))
        FileUtils.mkdir_p(rails_root.join("script"))
        FileUtils.cp(
          Rails.root.join("script/discourse_vips_broker"),
          rails_root.join("script/discourse_vips_broker"),
        )
        FileUtils.ln_s(
          Rails.root.join("lib/discourse_vips/configuration.rb"),
          rails_root.join("lib/discourse_vips/configuration.rb"),
        )
        File.write(rails_root.join("Gemfile"), "")
        if broker_contents
          File.write(rails_root.join("lib/discourse_vips/broker.rb"), broker_contents)
        end
        rails_root
      end

      it "removes the pid file owned by the failed process" do
        Dir.mktmpdir do |temporary_directory|
          rails_root = prepare_failing_broker_root(temporary_directory:)
          daemon = described_class.new(0, rails_root:)

          daemon.run
          _, status = Process.wait2(daemon.pid)

          expect([status.success?, File.exist?(daemon.pid_file)]).to eq([false, false])
        end
      end

      it "preserves a pid file replaced before the failed process exits" do
        Dir.mktmpdir do |temporary_directory|
          rails_root = Pathname(temporary_directory)
          daemon = described_class.new(0, rails_root:)
          replacement_pid = (Process.pid + 1_000_000).to_s
          broker_contents = <<~RUBY
            File.write(#{daemon.pid_file.dump}, #{replacement_pid.dump})
            raise "broker boot failed"
          RUBY
          prepare_failing_broker_root(temporary_directory:, broker_contents:)

          daemon.run
          _, status = Process.wait2(daemon.pid)

          expect([status.success?, File.read(daemon.pid_file)]).to eq([false, replacement_pid])
        end
      end
    end
  end
end
