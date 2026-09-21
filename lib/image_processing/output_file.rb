# frozen_string_literal: true

require "tempfile"

module ImageProcessing
  module OutputFile
    def self.write(path)
      Tempfile.create(["image-output-", File.extname(path)]) do |output|
        result = yield output.path
        output.rewind

        File.open(path, "wb") { |destination| IO.copy_stream(output, destination) }

        result
      end
    end
  end
end
