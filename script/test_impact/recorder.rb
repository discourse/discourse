# frozen_string_literal: true

# Records what each spec file depends on (TEST_IMPACT_RECORD=1), for
# script/test_impact/build_map and select: the application code it ran, the
# site settings it read, the translation keys and locales it looked up, and
# the data files it read, and for system specs the browser JavaScript it
# ran. Started before the app loads, so Coverage sees every file; what boot
# did is dropped before each spec file, since eager loading runs every class
# body and loads every setting.
#
# Writes tmp/test_impact/recording-<TEST_ENV_NUMBER>-<pid>.jsonl.gz:
#   {"spec": "spec/models/post_spec.rb", "files": {"app/models/post.rb": [[12, 30]]},
#    "settings": ["max_post_length"], "keys": ["post.edit"], "locales": ["en"],
#    "reads": ["spec/fixtures/images/logo.png"],
#    "js": {"app-a1b2.digested.js": [[1, 52, 1, 90]]}}
#   {"methods": {"app/models/post.rb": [[12, 30]]},
#    "js_functions": {"app-a1b2.digested.js": [[1, 52, 1, 90]]}}  (last line)
#
# JavaScript is recorded as bundle line/column ranges of the functions that
# ran; script/test_impact/resolve_js maps them to source files through the
# build's source maps.
require "coverage"
require "fileutils"
require "json"
require "net/http"
require "open3"
require "tmpdir"
require "uri"
require "zlib"

module TestImpact
  class Recorder
    ROOT = File.expand_path("../..", __dir__)

    EXCLUDED = %r{\A(?:vendor|node_modules|tmp|public|frontend)/|_spec\.rb\z}

    NOTES = %i[settings keys locales reads].freeze

    def self.start
      raise "TEST_IMPACT_RECORD and COVERAGE both need Coverage; set one" if ENV["COVERAGE"]
      # eval: ActionView compiles templates with the template's path as the file.
      Coverage.start(lines: true, methods: true, eval: true)
      @instance = new
    end

    def self.install(rspec_config)
      recorder = @instance or return
      recorder.hook_lookups
      rspec_config.before(:context) { recorder.reset }
      rspec_config.after(:context) { recorder.record(self.class.metadata[:file_path]) }
      rspec_config.before(:each, type: :system) { recorder.start_js(page) }
      rspec_config.after(:each, type: :system) { recorder.stop_js(page) }
      rspec_config.after(:suite) { recorder.finish }
    end

    def initialize
      @methods = {}
      @notes = NOTES.to_h { |kind| [kind, Set.new] }
      @js_ran = Hash.new { |h, script| h[script] = Set.new }
      @js_functions = Hash.new { |h, script| h[script] = Set.new }
      @line_starts = {}
    end

    # Settings and translations are loaded once at boot, so it's the lookups,
    # not the files, that tell specs apart.
    def hook_lookups
      recorder = self

      settings =
        Module.new do
          SiteSetting.defaults.all.keys.each do |name|
            [name, :"#{name}?"].each do |method|
              next if !SiteSetting.respond_to?(method)
              define_method(method) do |*args, &block|
                recorder.note(:settings, name.to_s)
                super(*args, &block)
              end
            end
          end
        end
      SiteSetting.singleton_class.prepend(settings)

      translations =
        Module.new do
          %i[translate t exists?].each do |method|
            define_method(method) do |*args, &block|
              recorder.note_translation(args)
              super(*args, &block)
            end
          end
        end
      I18n.singleton_class.prepend(translations)

      reads =
        Module.new do
          %i[open read readlines foreach binread].each do |method|
            define_method(method) do |*args, **kwargs, &block|
              recorder.note_read(args.first)
              super(*args, **kwargs, &block)
            end
          end
        end
      File.singleton_class.prepend(reads)
    end

    def note(kind, value)
      @notes[kind] << value
    end

    def note_translation(args)
      options = args.last.is_a?(Hash) ? args.last : {}
      locale = options[:locale] || (args[1] if args[1].is_a?(Symbol) || args[1].is_a?(String))
      note(:locales, (locale || I18n.locale).to_s)
      scope = Array(options[:scope]).join(".")
      Array(args.first).each do |key|
        next if key.nil? || key.is_a?(Hash)
        note(:keys, scope.empty? ? key.to_s : "#{scope}.#{key}")
      end
    end

    def note_read(path)
      return if !(path.is_a?(String) || path.is_a?(Pathname))
      path = relative(File.expand_path(path.to_s)) or return
      note(:reads, path) if !path.end_with?(".rb")
    end

    # One DevTools port per browser the system specs launch (desktop, mobile,
    # per allowed host), for cdp_coverage.
    def self.chrome_args(driver_name)
      return [] if !@instance
      @ports ||= {}
      @ports[driver_name] ||= 9300 + (ENV["TEST_ENV_NUMBER"].to_i * 20) + @ports.size
      ["--remote-debugging-port=#{@ports[driver_name]}"]
    end

    def self.ports
      (@ports || {}).values
    end

    # Coverage goes through script/test_impact/cdp_coverage's own connection:
    # through the test's Playwright client a page's coverage takes minutes.
    def start_js(page)
      target_id =
        page.driver.with_playwright_page do |pw|
          session = pw.context.new_cdp_session(pw)
          session.send_message("Target.getTargetInfo").dig("targetInfo", "targetId")
        ensure
          session&.detach
        end
      port = Recorder.ports.find { |candidate| page_on?(candidate, target_id) } or return
      @js_output = File.join(Dir.tmpdir, "test-impact-js-#{Process.pid}.json")
      @js_process =
        Open3.popen2(
          File.join(ROOT, "script/test_impact/cdp_coverage"),
          port.to_s,
          target_id,
          @js_output,
        )
      stdin, stdout, waiter = @js_process
      return if IO.select([stdout], nil, nil, 30) && stdout.gets&.strip == "started"
      warn "test impact: no JavaScript coverage for this example"
      stdin.close
      waiter.join(5)
      @js_process = nil
    end

    def stop_js(_page)
      stdin, _stdout, waiter = @js_process
      return if !waiter
      @js_process = nil
      stdin.puts("take")
      stdin.close
      return warn("test impact: JavaScript coverage timed out") if !waiter.join(120)
      return if !waiter.value.success? || !File.exist?(@js_output)
      record_js(JSON.parse(File.read(@js_output)))
    ensure
      File.delete(@js_output) if @js_output && File.exist?(@js_output)
    end

    def reset
      Coverage.result(stop: false, clear: true)
      @notes.each_value(&:clear)
      @started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def record(spec)
      files = {}
      Coverage
        .result(stop: false, clear: true)
        .each do |absolute, coverage|
          path = relative(absolute) or next
          ran = ran(path, coverage)
          files[path] = ran if ran.any?
        end
      notes = @notes.transform_values { |values| values.to_a.sort }
      # What selecting the spec costs, recording included.
      seconds = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - @started).round(2)
      js = @js_ran.transform_values { |ranges| ranges.to_a.sort }
      out.puts(JSON.generate(spec: spec.delete_prefix("./"), seconds:, files:, **notes, js:))
      @notes.each_value(&:clear)
      @js_ran.clear
    end

    def finish
      return if !@out
      methods = @methods.transform_values { |m| m[:ranges].to_a.sort }
      js_functions = @js_functions.transform_values { |ranges| ranges.to_a.sort }
      @out.puts(JSON.generate(methods:, js_functions:))
      @out.close
    end

    private

    # Opened on the first spec file, so a process that runs none (turbo_rspec's
    # parent loads rails_helper too) leaves no recording.
    def out
      @out ||=
        begin
          dir = File.join(ROOT, "tmp", "test_impact")
          FileUtils.mkdir_p(dir)
          name = "recording-#{ENV["TEST_ENV_NUMBER"] || "0"}-#{Process.pid}.jsonl.gz"
          Zlib::GzipWriter.open(File.join(dir, name))
        end
    end

    def record_js(coverage)
      coverage.each do |entry|
        script = script_name(entry["url"]) or next
        starts = (@line_starts[entry["url"]] ||= line_starts(fetch(entry["url"])))
        Array(entry["functions"]).each do |function|
          whole = function["ranges"]&.first or next
          range = [
            *position(starts, whole["startOffset"]),
            *position(starts, whole["endOffset"] - 1),
          ]
          @js_functions[script] << range
          @js_ran[script] << range if whole["count"].to_i > 0
        end
      end
    end

    def page_on?(port, target_id)
      targets = JSON.parse(Net::HTTP.get(URI("http://127.0.0.1:#{port}/json/list")))
      targets.any? { |target| target["id"] == target_id }
    rescue StandardError
      false
    end

    # The app's own scripts, by file name (digested, so unique per build).
    def script_name(url)
      path = URI.parse(url.to_s).path.to_s
      File.basename(path) if path.end_with?(".js")
    rescue URI::InvalidURIError
      nil
    end

    # Once per script per process, only to turn offsets into lines.
    def fetch(url)
      Net::HTTP.get(URI(url)).force_encoding(Encoding::UTF_8)
    rescue StandardError
      ""
    end

    # V8 counts offsets in UTF-16 code units, as source maps count columns.
    def line_starts(source)
      starts = [0]
      units = 0
      source.each_char do |char|
        units += char.ord > 0xFFFF ? 2 : 1
        starts << units if char == "\n"
      end
      starts
    end

    def position(starts, offset)
      line = starts.bsearch_index { |start| start > offset } || starts.size
      [line, offset - starts[line - 1] + 1]
    end

    def relative(absolute)
      return if !absolute.start_with?("#{ROOT}/")
      path = absolute.delete_prefix("#{ROOT}/")
      path if !EXCLUDED.match?(path)
    end

    # The methods that ran, plus runs of lines that ran outside every method:
    # blocks handed to class-level DSL (scopes, callbacks, event handlers).
    def ran(path, coverage)
      methods = coverage[:methods] || {}
      known = (@methods[path] ||= { ranges: Set.new, inside: Set.new })
      ran = []
      methods.each do |(_klass, _name, first, _, last, _), count|
        range = [first, last]
        known[:inside].merge(first..last) if known[:ranges].add?(range)
        ran << range if count > 0
      end

      run_start = nil
      lines = coverage[:lines] || []
      lines.each_with_index do |count, index|
        line = index + 1
        if count.to_i > 0 && !known[:inside].include?(line)
          run_start ||= line
        elsif run_start
          ran << [run_start, line - 1]
          run_start = nil
        end
      end
      ran << [run_start, lines.size] if run_start
      ran.uniq.sort
    end
  end
end
