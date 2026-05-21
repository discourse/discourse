# frozen_string_literal: true

class Downloads
  FOLDER = Rails.root.join("tmp/downloads")
  TIMEOUT = 10

  # Waits for `path` to appear and finish writing.
  def self.wait_for(path)
    previous_size = -1
    Timeout.timeout(TIMEOUT) do
      loop do
        size = File.size?(path)
        break if size == previous_size

        previous_size = size if size
        sleep 0.1
      end
    end
  rescue Timeout::Error
    last = previous_size == -1 ? "never appeared" : "last size #{previous_size}"
    raise Timeout::Error, "Timed out after #{TIMEOUT}s waiting for #{path} (#{last})"
  end

  def self.clear
    FileUtils.rm_rf(FOLDER)
  end
end
