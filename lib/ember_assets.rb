# frozen_string_literal: true

class EmberAssets < ActiveSupport::CurrentAttributes
  # Cache which persists for the duration of a request
  attribute :request_cache

  class BuildError < StandardError
    attr_reader :details

    def initialize(details)
      @details = details
      super(details.dig("error", "message") || "Frontend build failed")
    end
  end

  def self.dist_dir
    "#{Rails.root.join("frontend/discourse/dist")}"
  end

  def self.assets
    raise_if_build_error!
    cache[:assets] ||= Dir.glob("**/*.{js,map,txt,css}", base: "#{dist_dir}/assets")
  end

  def self.script_chunks(exception: true)
    raise_if_build_error! if exception
    return cache[:script_chunks] if cache[:script_chunks]

    entrypoints = {}

    manifest = read_manifest!(exception: exception)
    return {} if manifest.nil?

    {
      **manifest["entrypoints"],
      **manifest["dynamicEntrypoints"],
    }.each do |entry_name, entry_filename|
      entrypoints[entry_name.delete_suffix(".js")] = deep_imports_for(
        chunk_filename: entry_filename,
        chunks: manifest["chunks"],
      ).map { it.delete_prefix("assets/").delete_suffix(".js") }
    end

    cache[:script_chunks] = entrypoints
  end

  def self.deep_imports_for(chunk_filename:, chunks:, seen: Set.new)
    return [] unless seen.add?(chunk_filename)
    [
      chunk_filename,
      *chunks
        .dig(chunk_filename, "imports")
        &.flat_map { |import| deep_imports_for(chunk_filename: import, chunks:, seen:) },
    ]
  end

  BUILD_WAIT_TIMEOUT = 20.0
  BUILD_POLL_INTERVAL = 0.05

  def self.build_error
    return nil unless Rails.env.local?
    return cache[:build_error] if cache.key?(:build_error)

    cache[:build_error] = wait_for_build
  end

  # Polls dist/manifest/build.json until the rolldown server reports a final
  # state (ok/error/crashed), the process dies, or we hit BUILD_WAIT_TIMEOUT.
  # Returns nil when everything is fine; returns an error payload otherwise.
  def self.wait_for_build
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + BUILD_WAIT_TIMEOUT
    loop do
      data = read_build_status
      return nil if data.nil?

      if data["pid"] && !pid_alive?(data["pid"])
        return data.merge("status" => "crashed", "error" => plain_error(<<~MSG))
          Rolldown process (pid #{data["pid"]}) is no longer running.
          Start it with `pnpm --dir frontend/discourse start`.
        MSG
      end

      case data["status"]
      when "error", "crashed"
        return data
      when "building"
        if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
          return(
            data.merge(
              "status" => "crashed",
              "error" =>
                plain_error("Frontend build did not complete within #{BUILD_WAIT_TIMEOUT.to_i}s."),
            )
          )
        end
        sleep BUILD_POLL_INTERVAL
      else
        return nil
      end
    end
  end

  def self.read_build_status
    data = JSON.parse(File.read("#{dist_dir}/manifest/build.json"))
    data.is_a?(Hash) ? data : nil
  rescue Errno::ENOENT, JSON::ParserError
    nil
  end

  def self.pid_alive?(pid)
    Process.kill(0, pid.to_i)
    true
  rescue Errno::ESRCH, Errno::EPERM, ArgumentError, RangeError
    false
  end

  def self.raise_if_build_error!
    if (details = build_error)
      raise BuildError.new(details)
    end
  end

  # Reads the rolldown manifest. Returns the parsed hash, or nil when the
  # caller has opted out of raising. When `exception:` is true and the manifest
  # is missing, raises BuildError so the dev error page is shown.
  def self.read_manifest!(exception:)
    JSON.parse(File.read("#{dist_dir}/manifest/manifest.json"))
  rescue Errno::ENOENT
    if exception && Rails.env.local?
      raise BuildError.new("status" => "missing", "error" => plain_error(<<~MSG))
              No frontend build found at #{dist_dir}/manifest/manifest.json.
              Start the dev server with `pnpm --dir frontend/discourse start`.
            MSG
    end
    nil
  end

  # Build an error payload from plain text, populating both `message` (used in
  # the raised exception's message) and `messageHtml` (rendered in the dev
  # error view, HTML-escaped here since there are no ANSI codes to convert).
  def self.plain_error(text)
    { "message" => text, "messageHtml" => ERB::Util.html_escape(text) }
  end

  def self.is_ember_asset?(name)
    assets.include?(name) || script_chunks.values.flatten.include?(name.delete_suffix(".js"))
  end

  def self.has_tests?
    script_chunks["test-entrypoint"].present?
  end

  def self.cache
    if Rails.env.development?
      self.request_cache ||= {}
    else
      @production_cache ||= {}
    end
  end

  def self.clear_cache!
    self.request_cache = nil
    @production_cache = nil
  end

  def self.watch!
    FileUtils.mkdir_p("#{dist_dir}/manifest")
    Listen
      .to("#{dist_dir}/manifest") do |modified, added, removed|
        next if modified.size == 0 && added.size == 0
        next if read_build_status["status"] == "building"
        MessageBus.publish("/file-change", ["refresh"])
      end
      .start
  end
end
