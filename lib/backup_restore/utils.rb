module BackupRestore
  module Utils
    def execute_command(command, failure_message = "")
      output = `#{command} 2>&1`

      if !$?.success?
        failure_message = "#{failure_message}\n" if !failure_message.blank?
        raise "#{failure_message}#{output}"
      end

      output
    end

    def pretty_logs(logs)
      logs.join("\n")
    end
  end
end
