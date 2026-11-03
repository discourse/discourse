# frozen_string_literal: true

# Records the application code each spec file runs (TEST_IMPACT_RECORD=1),
# for script/test_impact/build_map and select. Started before the app loads,
# so Coverage sees every file; what boot ran is dropped before each spec
# file, since eager loading runs every class body.
#
# Writes tmp/test_impact/recording-<TEST_ENV_NUMBER>-<pid>.jsonl.gz:
#   {"spec": "spec/models/post_spec.rb", "files": {"app/models/post.rb": [[12, 30]]}}
#   {"methods": {"app/models/post.rb": [[12, 30]]}}  (last line)
require "coverage"
require "fileutils"
require "json"
require "zlib"

module TestImpact
  class Recorder
    ROOT = File.expand_path("../..", __dir__)

    EXCLUDED = %r{\A(?:vendor|node_modules|tmp|public|frontend)/|_spec\.rb\z}

    def self.start
      raise "TEST_IMPACT_RECORD and COVERAGE both need Coverage; set one" if ENV["COVERAGE"]
      # eval: ActionView compiles templates with the template's path as the file.
      Coverage.start(lines: true, methods: true, eval: true)
      @instance = new
    end

    def self.install(rspec_config)
      recorder = @instance or return
      rspec_config.before(:context) { recorder.reset }
      rspec_config.after(:context) { recorder.record(self.class.metadata[:file_path]) }
      rspec_config.after(:suite) { recorder.finish }
    end

    def initialize
      @methods = {}
    end

    def reset
      Coverage.result(stop: false, clear: true)
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
      out.puts(JSON.generate(spec: spec.delete_prefix("./"), files: files))
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
