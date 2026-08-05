# frozen_string_literal: true

require "digest"
require "json"
require "pathname"

class FlakyTestCandidate
  MAX_EXAMPLES = 3
  MAX_TEXT_LENGTH = 4_000

  def self.call(reports_dir:, minimum_occurrences:, minimum_workflow_runs:)
    new(reports_dir:, minimum_occurrences:, minimum_workflow_runs:).call
  end

  def initialize(reports_dir:, minimum_occurrences:, minimum_workflow_runs:)
    @reports_dir = Pathname(reports_dir)
    @minimum_occurrences = minimum_occurrences
    @minimum_workflow_runs = minimum_workflow_runs
  end

  def call
    candidate =
      grouped_failures
        .values
        .filter { |failure| eligible?(failure) }
        .max_by { |failure| [failure[:occurrences], failure[:workflow_runs].length, failure[:key]] }

    { candidate: candidate && serialize(candidate) }
  end

  private

  def grouped_failures
    failures = {}

    report_paths.each do |report_path|
      workflow_run_id = report_path.relative_path_from(@reports_dir).each_filename.first

      parse_report(report_path).each do |report|
        spec_path = normalized_spec_path(report["location_rerun_argument"])
        description = report["description"].to_s
        next if spec_path.empty? || description.empty?

        key = Digest::SHA256.hexdigest("#{spec_path}\0#{description}")
        failure =
          failures[key] ||= {
            key:,
            spec_path:,
            description:,
            occurrences: 0,
            workflow_runs: [],
            examples: [],
          }

        failure[:occurrences] += 1
        failure[:workflow_runs] << workflow_run_id
        if failure[:examples].length < MAX_EXAMPLES
          failure[:examples] << example(report, workflow_run_id)
        end
      end
    end

    failures.each_value { |failure| failure[:workflow_runs].uniq! }
  end

  def report_paths
    @reports_dir.glob("**/*.json").sort
  end

  def parse_report(report_path)
    parsed = JSON.parse(report_path.read)
    parsed.is_a?(Array) ? parsed.filter { |entry| entry.is_a?(Hash) } : []
  rescue JSON::ParserError, Errno::ENOENT
    []
  end

  def normalized_spec_path(location)
    location.to_s.sub(%r{\A\./}, "").sub(/:\d+\z/, "")
  end

  def eligible?(failure)
    failure[:occurrences] >= @minimum_occurrences &&
      failure[:workflow_runs].length >= @minimum_workflow_runs
  end

  def example(report, workflow_run_id)
    {
      workflow_run_id:,
      exception_name: report["exception_name"],
      exception_message: truncate(report["exception_message"]),
      message_lines: truncate(report["message_lines"]),
      backtrace: Array(report["backtrace"]).first(20).map { |line| truncate(line) },
      rerun_command: truncate(report["rerun_command"]),
    }
  end

  def truncate(value)
    value.to_s.slice(0, MAX_TEXT_LENGTH)
  end

  def serialize(failure)
    failure.merge(workflow_runs: failure[:workflow_runs].sort)
  end
end
