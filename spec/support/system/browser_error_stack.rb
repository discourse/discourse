# frozen_string_literal: true
require "open3"

module BrowserErrorStack
  def self.resolve(messages)
    return messages if ENV["DISCOURSE_CI_MINIFY"] != "1" || messages.empty?

    env = {}
    if (cli_path = ENV["PLAYWRIGHT_CLI_EXECUTABLE_PATH"])
      env["NODE_PATH"] = [
        File.expand_path("..", File.dirname(cli_path)),
        ENV["NODE_PATH"],
      ].compact.join(File::PATH_SEPARATOR)
    end
    output, _stderr, status =
      Open3.capture3(
        env,
        "node",
        Rails.root.join("frontend/discourse/lib/browser-error-stack.js").to_s,
        stdin_data: JSON.generate(messages),
      )
    if status.success?
      resolved = JSON.parse(output)
      if resolved.is_a?(Array) && resolved.size == messages.size &&
           resolved.all? { |message| message.is_a?(String) }
        return resolved
      end
    end

    failed_mapping(messages)
  rescue SystemCallError, JSON::ParserError
    failed_mapping(messages)
  end

  def self.failed_mapping(messages)
    warn "Browser stack mapping failed. Showing raw stacks."
    messages
  end
  private_class_method :failed_mapping
end
