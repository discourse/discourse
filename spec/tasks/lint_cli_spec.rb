# frozen_string_literal: true

require "fileutils"
require "tmpdir"

load Rails.root.join("bin/lint")

RSpec.describe LefthookLinter do
  it "reports when a core file has no configured linter" do
    expect { described_class.new(files: ["README.md"]).run }.to output(<<~OUTPUT).to_stdout
        [bin/lint] No core linter for: README.md
        [bin/lint] Nothing was linted
      OUTPUT
  end

  it "does not send non-plugin files outside the project to core linters" do
    Dir.mktmpdir("lint-outside", Rails.root.parent) do |directory|
      file = File.join(directory, "example.rb")
      File.write(file, "puts :example\n")
      relative_file = Pathname.new(file).relative_path_from(PROJECT_ROOT_PATH)

      expect { described_class.new(files: [file]).run }.to output(<<~OUTPUT).to_stdout
          [bin/lint] No core linter for: #{relative_file}
          [bin/lint] Nothing was linted
        OUTPUT
    end
  end

  it "expands symlinked directories returned by git" do
    Dir.mktmpdir("lint-symlink") do |directory|
      original_path = ENV.fetch("PATH")
      original_invocation_log = ENV["LINT_SPEC_INVOCATIONS"]
      target = File.join(directory, "target")
      fake_bin = File.join(directory, "bin")
      invocation_log = File.join(directory, "invocations")
      symlink = Rails.root.join("themes", "lint-spec-#{Process.pid}")

      FileUtils.mkdir_p([target, fake_bin])
      File.write(File.join(target, "example.rb"), "puts :example\n")
      File.symlink(target, symlink)
      File.write(
        File.join(fake_bin, "pnpm"),
        "#!/bin/sh\nprintf '%s\\n' \"$*\" >> \"$LINT_SPEC_INVOCATIONS\"\n",
      )
      FileUtils.chmod(0o755, File.join(fake_bin, "pnpm"))

      ENV["PATH"] = "#{fake_bin}:#{original_path}"
      ENV["LINT_SPEC_INVOCATIONS"] = invocation_log

      expect { described_class.new(files: [symlink.to_s]).run }.to output(
        %r{\[bin/lint\] All lints passed},
      ).to_stdout
      expect(File.read(invocation_log)).to include(
        "lefthook run lint-files --file themes/#{symlink.basename}/example.rb",
      )
    ensure
      ENV["PATH"] = original_path
      ENV["LINT_SPEC_INVOCATIONS"] = original_invocation_log
      FileUtils.rm_f(symlink)
    end
  end
end

RSpec.describe ExternalLinter do
  it "batches large file sets for each external linter" do
    Dir.mktmpdir("external-lint") do |directory|
      original_path = ENV.fetch("PATH")
      original_invocation_log = ENV["LINT_SPEC_INVOCATIONS"]
      source_directory = File.join(directory, "lib")
      fake_bin = File.join(directory, "bin")
      invocation_log = File.join(directory, "invocations")

      FileUtils.mkdir_p([source_directory, fake_bin])
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

      File.write(File.join(fake_bin, "bundle"), <<~RUBY)
          #!/usr/bin/env ruby
          File.open(ENV.fetch("LINT_SPEC_INVOCATIONS"), "a") { |file| file.puts(ARGV.join(" ")) }
        RUBY
      FileUtils.chmod(0o755, File.join(fake_bin, "bundle"))

      ENV["PATH"] = "#{fake_bin}:#{original_path}"
      ENV["LINT_SPEC_INVOCATIONS"] = invocation_log

      linter = described_class.new(directory, files, fix: false)
      expect { linter.run }.to output(%r{\[bin/lint\] Running rubocop}).to_stdout

      invocations = File.readlines(invocation_log, chomp: true)
      expect(invocations.count { |invocation| invocation.start_with?("exec stree check") }).to eq(2)
      expect(invocations.count { |invocation| invocation.start_with?("exec rubocop") }).to eq(2)
      expect(linter.results).to all(satisfy { |_, result| result })
    ensure
      ENV["PATH"] = original_path
      ENV["LINT_SPEC_INVOCATIONS"] = original_invocation_log
    end
  end
end
