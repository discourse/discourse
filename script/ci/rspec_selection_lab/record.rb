# frozen_string_literal: true

require "json"
require "fileutils"

ENV.delete("SPEC_OPTS")

class RspecSelectionLabRecorder
  RSpec::Core::Formatters.register self,
                                   :example_passed,
                                   :example_failed,
                                   :example_pending,
                                   :dump_summary,
                                   :close

  def initialize(_output)
    @examples = []
  end

  def example_passed(notification)
    @examples << { id: notification.example.id, status: "passed" }
  end

  def example_failed(notification)
    @examples << { id: notification.example.id, status: "failed" }
  end

  def example_pending(notification)
    @examples << { id: notification.example.id, status: "pending" }
  end

  def dump_summary(notification)
    @errors = notification.errors_outside_of_examples_count
  end

  def close(_notification)
    directory = ENV.fetch("RSPEC_LAB_RESULTS")
    FileUtils.mkdir_p(directory)
    File.write(
      "#{directory}/#{Process.pid}.json",
      JSON.generate(examples: @examples, errors: @errors, seed: RSpec.configuration.seed),
    )
  end
end

RSpec.configure { |config| config.add_formatter(RspecSelectionLabRecorder) }
