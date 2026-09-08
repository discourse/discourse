# frozen_string_literal: true

require "fileutils"
require "tmpdir"

load Rails.root.join("bin/lint")

module FakeExecutable
  INVOCATIONS_ENV = "LINT_SPEC_INVOCATIONS"
  RECORD_ARGUMENTS = "printf '%s\\n' \"$*\" >> \"$#{INVOCATIONS_ENV}\""

  def with_fake_executable(name, script = nil)
    Dir.mktmpdir("lint") do |directory|
      original_path = ENV.fetch("PATH")
      original_invocations = ENV[INVOCATIONS_ENV]
      fake_bin = File.join(directory, "bin")
      executable = File.join(fake_bin, name)
      invocations = File.join(directory, "invocations")

      FileUtils.mkdir_p(fake_bin)
      File.write(executable, ["#!/bin/sh", RECORD_ARGUMENTS, script].compact.join("\n") + "\n")
      FileUtils.chmod(0o755, executable)

      ENV["PATH"] = "#{fake_bin}:#{original_path}"
      ENV[INVOCATIONS_ENV] = invocations

      yield directory, invocations
    ensure
      ENV["PATH"] = original_path
      ENV[INVOCATIONS_ENV] = original_invocations
    end
  end
end

RSpec.describe LefthookLinter do
  include FakeExecutable

  it "reports when a core file has no configured linter" do
    expect { described_class.new(files: ["README.md"]).run }.to output(<<~OUTPUT).to_stdout
        [bin/lint] No core linter for: README.md
        [bin/lint] Nothing was linted
      OUTPUT
  end

  it "does not send non-plugin files outside the project to core linters" do
    expect_no_core_linter_outside_project("example.rb")
  end

  it "applies the skipped path list only inside the project" do
    expect_no_core_linter_outside_project("tmp/example.rb")
  end

  it "reports a failing linter without exiting the process" do
    with_fake_executable("pnpm", "exit 1") do
      expect { expect(described_class.new(files: ["Gemfile"]).run).to eq(false) }.to output(
        %r{\[bin/lint\] core linters failed},
      ).to_stdout
    end
  end

  it "fails on the first git error instead of linting nothing" do
    failing_git = "printf 'fatal: detected dubious ownership\\n' >&2\nexit 128"

    with_fake_executable("git", failing_git) do |_directory, invocations|
      expect { expect(described_class.new(recent: true).run).to eq(false) }.to output(
        %r{\[bin/lint\] git log failed: fatal: detected dubious ownership},
      ).to_stderr
      expect(File.readlines(invocations).size).to eq(1)
    end
  end

  it "expands symlinked directories returned by git" do
    symlink = Rails.root.join("themes", "lint-spec-#{Process.pid}")

    with_fake_executable("pnpm") do |directory, invocations|
      target = File.join(directory, "target")

      FileUtils.mkdir_p(target)
      File.write(File.join(target, "example.rb"), "puts :example\n")
      File.symlink(target, symlink)

      expect { described_class.new(files: [symlink.to_s]).run }.to output(
        %r{\[bin/lint\] All lints passed},
      ).to_stdout
      expect(File.read(invocations)).to include(
        "lefthook run lint-files --file themes/#{symlink.basename}/example.rb",
      )
    ensure
      FileUtils.rm_f(symlink)
    end
  end

  def expect_no_core_linter_outside_project(relative_path)
    Dir.mktmpdir("lint") do |directory|
      file = File.join(directory, relative_path)
      FileUtils.mkdir_p(File.dirname(file))
      File.write(file, "puts :example\n")
      relative_file = Pathname.new(file).relative_path_from(PROJECT_ROOT_PATH)

      expect { described_class.new(files: [file]).run }.to output(<<~OUTPUT).to_stdout
          [bin/lint] No core linter for: #{relative_file}
          [bin/lint] Nothing was linted
        OUTPUT
    end
  end
end

RSpec.describe ExternalLinter do
  include FakeExecutable

  it "batches large file sets for each external linter" do
    with_fake_executable("bundle") do |directory, invocations|
      source_directory = File.join(directory, "lib")

      FileUtils.mkdir_p(source_directory)
      files = []
      argument_bytes = 0
      index = 0
      while argument_bytes <= ArgumentBatcher::MAX_ARGV_BYTES + 1_000
        relative_path = File.join("lib", "#{index.to_s.rjust(3, "0")}-#{"x" * 220}.rb")
        path = File.join(directory, relative_path)
        File.write(path, "puts :example\n")
        files << path
        argument_bytes += relative_path.bytesize + 1
        index += 1
      end

      linter = described_class.new(directory, files, fix: false)
      expect { linter.run }.to output(%r{\[bin/lint\] Running rubocop}).to_stdout

      recorded = File.readlines(invocations, chomp: true)
      expect(recorded.count { |invocation| invocation.start_with?("exec stree check") }).to eq(2)
      expect(recorded.count { |invocation| invocation.start_with?("exec rubocop") }).to eq(2)
      expect(linter.results).to all(satisfy { |_, result| result })
    end
  end
end
