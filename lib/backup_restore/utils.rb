require 'open3'

module BackupRestore
  module Utils
    def execute_command(*command, failure_message: "")
      stdout, stderr, status = Open3.capture3(*command)

      if !status.success?
        failure_message = "#{failure_message}\n" if !failure_message.blank?
        raise "#{failure_message}#{stderr}"
      end

      stdout
    end

    def pretty_logs(logs)
      logs.join("\n")
    end
  end
end
