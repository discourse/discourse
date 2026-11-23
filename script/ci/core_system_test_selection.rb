# frozen_string_literal: true

require "json"
require "net/http"
require "open3"
require "time"
require "uri"

module CoreSystemTestSelection
  ARTIFACT = "core-system-test-map-v1"
  MAP_VERSION = 1
  SHA = /\A[0-9a-f]{40}\z/
  TEST_FILE = %r{\Aspec/system/.+_spec\.rb\z}
  DEPENDENCY_FILES = %w[Gemfile Gemfile.lock package.json pnpm-lock.yaml pnpm-workspace.yaml].freeze

  def self.git(*args)
    stdout, stderr, status = Open3.capture3("git", *args)
    raise "git #{args.first} failed: #{stderr.strip}" unless status.success?
    stdout
  end

  def self.inventory
    git("ls-files", "-z", "--", "spec/system").split("\0").grep(TEST_FILE).sort
  end

  def self.ancestor?(older, newer)
    return false unless SHA.match?(older.to_s) && SHA.match?(newer.to_s)
    _, _, status = Open3.capture3("git", "merge-base", "--is-ancestor", older, newer)
    status.success?
  end

  def self.changed_paths(from, to)
    git("diff", "--name-only", "-z", "--no-renames", from, to, "--").split("\0")
  end

  def self.artifact_candidates
    repo = ENV.fetch("GITHUB_REPOSITORY")
    repo_id = Integer(ENV.fetch("GITHUB_REPOSITORY_ID"), 10)
    uri = URI("#{ENV.fetch("GITHUB_API_URL")}/repos/#{repo}/actions/artifacts")
    uri.query = URI.encode_www_form(name: ARTIFACT, per_page: 30)
    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "Bearer #{ENV.fetch("GH_TOKEN")}"
    request["Accept"] = "application/vnd.github+json"
    response =
      Net::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: uri.scheme == "https",
        open_timeout: 5,
        read_timeout: 10,
      ) { |http| http.request(request) }
    unless response.is_a?(Net::HTTPSuccess)
      raise "GitHub artifact listing returned #{response.code}"
    end
    JSON
      .parse(response.body)
      .fetch("artifacts")
      .select do |artifact|
        run = artifact.fetch("workflow_run")
        !artifact.fetch("expired") && run.fetch("head_branch") == "main" &&
          run.fetch("repository_id") == repo_id && run.fetch("head_repository_id") == repo_id &&
          SHA.match?(run.fetch("head_sha")) && artifact.fetch("size_in_bytes") <= 5 * 1024 * 1024
      end
      .sort_by { |artifact| artifact.fetch("created_at") }
      .reverse
  end

  def self.ci_base
    ENV
      .fetch("CORE_SYSTEM_PR_BASE")
      .tap do |base|
        raise "Unknown CI base" unless SHA.match?(base) && git("rev-parse", "HEAD^1").strip == base
      end
  end

  def self.write_outputs(**values)
    File.open(ENV.fetch("GITHUB_OUTPUT"), "a") do |file|
      values.each { |key, value| file.puts "#{key}=#{value}" }
    end
  end

  def self.select(files:, map:, base:, tested:)
    revision = map.fetch("revision")
    raise "Map schema differs" unless map.fetch("version") == MAP_VERSION
    raise "Map revision differs from artifact" unless revision == ENV["CORE_SYSTEM_MAP_SHA"]
    raise "Map is outside the base ancestry" unless ancestor?(revision, base)

    drift = changed_paths(revision, base)
    pr = changed_paths(base, tested)
    paths = drift | pr
    map_files = map.fetch("spec_files").to_set
    dependencies = map.fetch("tests_by_source")
    boot = map.fetch("boot_sources").to_set
    selected = Set.new

    if (files.to_set - map_files - paths).any?
      return decision(files:, reason: "inventory_discrepancy", drift:, pr:, revision:)
    end

    inputs =
      paths.reject do |path|
        path.start_with?("docs/") ||
          (path.match?(%r{\Aspec/.+_spec\.rb\z}) && !TEST_FILE.match?(path))
      end
    inputs.each do |path|
      if TEST_FILE.match?(path)
        selected.add(path)
      elsif boot.include?(path) || DEPENDENCY_FILES.include?(File.basename(path))
        return decision(files:, reason: "shared_input", drift:, pr:, revision:)
      elsif dependencies.key?(path)
        selected.merge(dependencies.fetch(path))
      else
        return decision(files:, reason: "unmapped_input", drift:, pr:, revision:)
      end
    end

    selected &= files.to_set
    if selected.empty? && inputs.any?
      return decision(files:, reason: "empty_selection", drift:, pr:, revision:)
    end
    decision(files:, selected: selected.to_a.sort, drift:, pr:, revision:)
  end

  def self.decision(files:, reason: nil, selected: files, drift: [], pr: [], revision: nil)
    {
      map_revision: revision,
      total_files: files.size,
      selected_files: selected,
      fewer_files: files.size - selected.size,
      full_suite_fallback: reason,
      main_drift: drift.sort,
      pull_request_changes: pr.sort,
    }
  end

  def self.plan(map_file:, output:)
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    files = inventory
    result =
      begin
        if File.file?(map_file)
          select(files:, map: JSON.parse(File.read(map_file)), base: ci_base, tested: "HEAD")
        else
          decision(files:, reason: "no_compatible_map")
        end
      rescue StandardError => error
        warn "Core system selection fallback: #{error.message}"
        decision(files:, reason: "selection_error")
      end
    result[:selector_seconds] = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start).round(3)
    File.write(output, JSON.generate(result))
  end
end

if $PROGRAM_NAME == __FILE__
  case ARGV.shift
  when "due"
    latest = CoreSystemTestSelection.artifact_candidates.first
    due = latest.nil? || Time.now - Time.iso8601(latest.fetch("created_at")) >= 86_400
    CoreSystemTestSelection.write_outputs(due:)
  when "find"
    base = CoreSystemTestSelection.ci_base
    artifact =
      CoreSystemTestSelection.artifact_candidates.find do |candidate|
        CoreSystemTestSelection.ancestor?(candidate.fetch("workflow_run").fetch("head_sha"), base)
      end
    if artifact
      run = artifact.fetch("workflow_run")
      CoreSystemTestSelection.write_outputs(
        artifact_id: Integer(artifact.fetch("id")),
        revision: run.fetch("head_sha"),
        run_id: Integer(run.fetch("id")),
      )
    end
  when "plan"
    CoreSystemTestSelection.plan(map_file: ARGV.fetch(0), output: ARGV.fetch(1))
  else
    abort "Expected due, find or plan"
  end
end
