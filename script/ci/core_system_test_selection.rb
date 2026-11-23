# frozen_string_literal: true

require "json"
require "net/http"
require "open3"
require "prism"
require "uri"

module CoreSystemTestSelection
  ARTIFACT = "core-system-test-map-v2"
  MAP_VERSION = 2
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

  def self.find_artifact
    write_outputs(started_at: Process.clock_gettime(Process::CLOCK_MONOTONIC))
    candidates = artifact_candidates
    return if candidates.empty?

    if git("rev-parse", "--is-shallow-repository").strip == "true"
      tested = git("rev-parse", "HEAD").strip
      git("fetch", "--no-tags", "--filter=blob:none", "--unshallow", "origin", tested)
    end
    base = ci_base
    artifact =
      candidates.find do |candidate|
        ancestor?(candidate.fetch("workflow_run").fetch("head_sha"), base)
      end
    return if !artifact

    run = artifact.fetch("workflow_run")
    write_outputs(
      artifact_id: Integer(artifact.fetch("id")),
      revision: run.fetch("head_sha"),
      run_id: Integer(run.fetch("id")),
    )
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

  def self.method_bodies(source)
    parsed = Prism.parse(source)
    return unless parsed.success?

    bodies = []
    nodes = [parsed.value]
    until nodes.empty?
      node = nodes.pop
      if node.is_a?(Prism::DefNode)
        bodies << node.body&.location
      else
        nodes.concat(node.compact_child_nodes.reverse)
      end
    end
    bodies
  end

  def self.outside_method_bodies(source:, bodies:, indexes:)
    offset = 0
    parts =
      indexes.map do |index|
        body = bodies.fetch(index)
        part = source.byteslice(offset...body.start_offset)
        offset = body.end_offset
        part
      end
    parts << source.byteslice(offset..)
  end

  def self.runtime_body_change?(path:, revisions:, boot_lines:)
    snapshots = revisions.uniq.map { |commit| git("show", "#{commit}:#{path}") }
    bodies_by_revision = snapshots.map { |source| method_bodies(source) }
    return false if bodies_by_revision.any?(&:nil?)

    original_bodies = bodies_by_revision.first
    return false unless bodies_by_revision.all? { |bodies| bodies.size == original_bodies.size }

    executed_at_boot = boot_lines.to_set
    indexes =
      original_bodies.each_index.select do |index|
        body = original_bodies[index]
        body && (body.start_line..body.end_line).none? { |line| executed_at_boot.include?(line) } &&
          bodies_by_revision.all? { |bodies| bodies[index] }
      end
    return false if indexes.empty?

    snapshots
      .zip(bodies_by_revision)
      .map { |source, bodies| outside_method_bodies(source:, bodies:, indexes:) }
      .uniq
      .one?
  rescue RuntimeError
    false
  end
  private_class_method :method_bodies, :outside_method_bodies, :runtime_body_change?

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
    boot_lines = map.fetch("boot_lines")
    selected = Set.new
    unmapped_browser_specs = map.fetch("unmapped_browser_specs")

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
      elsif DEPENDENCY_FILES.include?(File.basename(path)) ||
            (
              boot.include?(path) &&
                !(
                  dependencies.key?(path) && boot_lines.key?(path) &&
                    runtime_body_change?(
                      path:,
                      revisions: [revision, base, tested],
                      boot_lines: boot_lines.fetch(path),
                    )
                )
            )
        return decision(files:, reason: "shared_input", drift:, pr:, revision:)
      elsif dependencies.key?(path)
        selected.merge(dependencies.fetch(path))
        selected.merge(unmapped_browser_specs)
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
    start =
      Float(ENV["CORE_SYSTEM_SELECTION_STARTED_AT"], exception: false) ||
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
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
  when "find"
    CoreSystemTestSelection.find_artifact
  when "plan"
    CoreSystemTestSelection.plan(map_file: ARGV.fetch(0), output: ARGV.fetch(1))
  else
    abort "Expected find or plan"
  end
end
