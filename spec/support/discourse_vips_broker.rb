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
    broker_pid = DiscourseVips.start
  end

  config.after(:suite) do
    begin
      Process.kill("TERM", broker_pid) if broker_pid
    rescue Errno::ESRCH
    end
    FileUtils.rm_f(socket_path) if socket_path
    FileUtils.rm_f("#{socket_path}.lock") if socket_path
    ENV.delete("DISCOURSE_VIPS_SOCKET_PATH")
  end
end
