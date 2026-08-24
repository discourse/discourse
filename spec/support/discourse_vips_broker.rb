# frozen_string_literal: true

RSpec.configure do |config|
  broker_pid = nil
  socket_path = nil

  config.before do |example|
    LetterAvatar.stubs(vips_version: "test") if !example.metadata[:with_vips_broker]
  end

  config.before(:suite) do
    broker_required =
      RSpec.world.filtered_examples.any? do |_group, examples|
        examples.any? { |example| example.metadata[:with_vips_broker] }
      end
    next if !broker_required

    socket_path = Rails.root.join("tmp", "discourse-vips-#{Process.pid}.sock").to_s
    ENV["DISCOURSE_VIPS_SOCKET_PATH"] = socket_path
    Discourse.before_fork

    broker_pid =
      fork do
        require "discourse_vips/broker"
        DiscourseVips::Broker.new(socket_path:, parent_pid: Process.ppid).run
        exit! 0
      end

    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
    until File.socket?(socket_path)
      if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
        raise "DiscourseVips test broker did not start"
      end

      sleep 0.01
    end
  end

  config.after(:suite) do
    if broker_pid
      begin
        Process.kill("TERM", broker_pid)
      rescue Errno::ESRCH
      end
      begin
        Process.wait(broker_pid)
      rescue Errno::ECHILD
      end
    end
    FileUtils.rm_f(socket_path) if socket_path
    ENV.delete("DISCOURSE_VIPS_SOCKET_PATH")
  end
end
