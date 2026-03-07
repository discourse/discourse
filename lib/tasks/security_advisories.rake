# frozen_string_literal: true

require "open3"

module SecurityAdvisoriesTask
  module_function

  def run(stdout: $stdout)
    advisories =
      fetch_advisories
        .select { |advisory| advisory.fetch("state") == "draft" }
        .reject { |advisory| advisory.fetch("summary").strip == "DRAFT" }

    advisories.each { |advisory| update_advisory!(advisory.fetch("ghsa_id"), stdout:) }
    stdout.puts "Updates count: #{advisories.size}"
  end

  def fetch_advisories
    pages = parse_json!(run_gh_api!(advisories_endpoint, "--paginate", "--slurp"))
    pages.flat_map { |page| page.is_a?(Array) ? page : [page] }
  end

  def update_advisory!(ghsa_id, stdout:)
    payload = { vulnerabilities: default_vulnerabilities }
    run_gh_api!(
      advisory_endpoint(ghsa_id),
      "--method",
      "PATCH",
      "--input",
      "-",
      input: JSON.pretty_generate(payload),
    )

    stdout.puts "Updated #{ghsa_id}"
  end

  def default_vulnerabilities
    [
      {
        package: {
          ecosystem: "other",
          name: "Discourse",
        },
        vulnerable_version_range: ">= 0",
        patched_versions: Discourse::VERSION::STRING,
      },
    ]
  end

  def advisories_endpoint
    "repos/discourse/discourse/security-advisories"
  end

  def advisory_endpoint(ghsa_id)
    "#{advisories_endpoint}/#{ghsa_id}"
  end

  def run_gh_api!(*args, input: nil)
    stdout_text, stderr_text, status = Open3.capture3("gh", "api", *args, stdin_data: input)

    return stdout_text if status.success?

    raise <<~MESSAGE
      gh api failed with status #{status.exitstatus}
      Command: gh api #{args.join(" ")}
      STDOUT:
      #{stdout_text}
      STDERR:
      #{stderr_text}
    MESSAGE
  end

  def parse_json!(json)
    JSON.parse(json)
  rescue JSON::ParserError => error
    $stderr.puts(json)
    raise "Unable to parse gh api response: #{error.message}"
  end
end

namespace :security_advisories do
  desc "Update advisory affected versions on GitHub for the current Discourse version"
  task update_affected_versions: :environment do
    SecurityAdvisoriesTask.run
  end
end
