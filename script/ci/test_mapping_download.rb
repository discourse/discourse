# frozen_string_literal: true
require "json"
require "net/http"
require "uri"
require "fileutils"
require "tmpdir"

module TestMappingDownload
  def self.latest(workflow:)
    raise ArgumentError, "Invalid workflow" unless %w[tests migration-tests].include?(workflow)
    repository = ENV.fetch("GITHUB_REPOSITORY")
    unless repository.match?(%r{\A[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+\z})
      raise ArgumentError, "Invalid repository"
    end
    api = ENV.fetch("GITHUB_API_URL", "https://api.github.com")
    artifacts =
      JSON.parse(
        request(
          uri:
            URI(
              "#{api}/repos/#{repository}/actions/artifacts?name=test-mapping-main-#{workflow}&per_page=20",
            ),
          api: api,
          limit_bytes: 1_000_000,
        ),
      ).fetch("artifacts")
    artifacts
      .reject do |artifact|
        artifact.fetch("expired") || artifact.fetch("size_in_bytes") > 200_000_000
      end
      .sort_by { |artifact| -artifact.fetch("workflow_run").fetch("id") }
      .each do |artifact|
        run =
          JSON.parse(
            request(
              uri:
                URI(
                  "#{api}/repos/#{repository}/actions/runs/#{artifact.fetch("workflow_run").fetch("id")}",
                ),
              api: api,
              limit_bytes: 1_000_000,
            ),
          )
        allowed_workflows = [".github/workflows/#{workflow}.yml"]
        allowed_workflows << ".github/workflows/test-mapping.yml"
        unless allowed_workflows.include?(run.fetch("path")) && run.fetch("event") == "push" &&
                 run.fetch("head_branch") == "main" && run.fetch("status") == "completed" &&
                 run.fetch("conclusion") == "success" &&
                 run.fetch("repository").fetch("full_name") == repository &&
                 run.fetch("head_repository").fetch("full_name") == repository
          next
        end
        return { "artifact" => artifact, "run" => run }
      end
    nil
  end

  def self.fetch(directory:, workflow:)
    producer = latest(workflow: workflow)
    unless producer
      warn "No completed main mapping is available"
      return
    end
    require "zip"
    artifact = producer.fetch("artifact")
    run = producer.fetch("run")
    api = ENV.fetch("GITHUB_API_URL", "https://api.github.com")
    repository = ENV.fetch("GITHUB_REPOSITORY")
    Dir.mktmpdir("test-mapping-") do |temporary|
      archive = "#{temporary}/mapping.zip"
      File.binwrite(
        archive,
        request(
          uri: URI("#{api}/repos/#{repository}/actions/artifacts/#{artifact.fetch("id")}/zip"),
          api: api,
          limit_bytes: 200_000_000,
        ),
      )
      mappings =
        Zip::File.open(archive) do |zip|
          entries = zip.entries
          paths = entries.map(&:name)
          unless paths.uniq == paths && paths.length <= 19 &&
                   paths.all? { |path| path.match?(/\A[a-z]+(?:-[a-z]+)*\.json\z/) }
            raise "Unexpected mapping entries"
          end
          entries.to_h do |entry|
            raise "Mapping entry exceeds size limit" if entry.size > 500_000_000
            content = +""
            entry.get_input_stream do |stream|
              while (chunk = stream.read(1_048_576))
                if content.bytesize + chunk.bytesize > 500_000_000
                  raise "Mapping entry exceeds size limit"
                end
                content << chunk
              end
            end
            mapping = JSON.parse(content)
            unless mapping.fetch("revision") == run.fetch("head_sha") &&
                     mapping.fetch("complete") && [2, 3].include?(mapping.fetch("version"))
              raise "Mapping producer differs from workflow"
            end
            [entry.name, content]
          end
        end
      FileUtils.mkdir_p(directory)
      mappings.each { |path, content| File.write(File.join(directory, path), content) }
      File.write(
        File.join(directory, "producer.json"),
        JSON.pretty_generate("revision" => run.fetch("head_sha"), "run_id" => run.fetch("id")),
      )
    end
  end

  def self.request(uri:, api:, limit_bytes:, redirects: 0)
    raise "Invalid artifact URL" unless uri.scheme == "https" && redirects <= 3
    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "Bearer #{ENV.fetch("GITHUB_TOKEN")}" if ENV["GITHUB_TOKEN"] &&
      uri.host == URI(api).host
    request["Accept"] = "application/vnd.github+json"
    content = +""
    redirect = nil
    Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 15, read_timeout: 30) do |http|
      http.request(request) do |response|
        if response.is_a?(Net::HTTPRedirection)
          redirect = URI.join(uri, response.fetch("location"))
        elsif response.is_a?(Net::HTTPSuccess)
          response.read_body do |chunk|
            if content.bytesize + chunk.bytesize > limit_bytes
              raise "Mapping response exceeds size limit"
            end
            content << chunk
          end
        else
          raise "Mapping request failed with HTTP #{response.code}"
        end
      end
    end
    if redirect
      request(uri: redirect, api: api, limit_bytes: limit_bytes, redirects: redirects + 1)
    else
      content
    end
  end
  private_class_method :request
end

if $PROGRAM_NAME == __FILE__
  begin
    raise ArgumentError, "Expected DIRECTORY WORKFLOW" unless ARGV.length == 2
    TestMappingDownload.fetch(directory: ARGV[0], workflow: ARGV[1])
  rescue StandardError => error
    warn "Mapping unavailable: #{error.message}"
    exit 1
  end
end
