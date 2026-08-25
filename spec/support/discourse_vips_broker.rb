# frozen_string_literal: true

RSpec.configure do |config|
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
    at_exit do
      FileUtils.rm_f(socket_path)
      FileUtils.rm_f("#{socket_path}.lock")
    end
  end

  config.after(:suite) { ENV.delete("DISCOURSE_VIPS_SOCKET_PATH") }
end
