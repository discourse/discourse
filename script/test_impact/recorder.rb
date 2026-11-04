# frozen_string_literal: true

# Records what each spec file depends on (TEST_IMPACT_RECORD=1), for
# script/test_impact/build_map and select: the application code it ran, the
# site settings it read, the translation keys and locales it looked up, and
# the data files it read. Started before the app loads, so Coverage sees
# every file; what boot did is dropped before each spec file, since eager
# loading runs every class body and loads every setting.
#
# Writes tmp/test_impact/recording-<TEST_ENV_NUMBER>-<pid>.jsonl.gz:
#   {"spec": "spec/models/post_spec.rb", "files": {"app/models/post.rb": [[12, 30]]},
#    "settings": ["max_post_length"], "keys": ["post.edit"], "locales": ["en"],
#    "reads": ["spec/fixtures/images/logo.png"]}
#   {"methods": {"app/models/post.rb": [[12, 30]]}}  (last line)
require "coverage"
require "fileutils"
require "json"
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
      rspec_config.after(:suite) { recorder.finish }
    end

    def initialize
      @methods = {}
      @notes = NOTES.to_h { |kind| [kind, Set.new] }
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
      out.puts(JSON.generate(spec: spec.delete_prefix("./"), seconds:, files:, **notes))
      @notes.each_value(&:clear)
    end

    def finish
      return if !@out
      methods = @methods.transform_values { |m| m[:ranges].to_a.sort }
      @out.puts(JSON.generate(methods: methods))
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
