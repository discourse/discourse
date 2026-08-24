# frozen_string_literal: true

RSpec.configure do |config|
  broker_daemon = nil
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
    require "demon/discourse_vips"
    broker_daemon = Demon::DiscourseVips.new("spec-#{Process.pid}")
    broker_daemon.start

    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
    loop do
      begin
        break if DiscourseVips.version(expected_broker_pid: broker_daemon.pid)
      rescue DiscourseVips::Error
      end

      if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
        raise "DiscourseVips test broker did not start"
      end

      sleep 0.01
    end
  end

  config.after(:suite) do
    broker_daemon&.stop
    FileUtils.rm_f(socket_path) if socket_path
    ENV.delete("DISCOURSE_VIPS_SOCKET_PATH")
  end
end
