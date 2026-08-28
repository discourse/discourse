# frozen_string_literal: true

require "open3"
require "tmpdir"

RSpec.describe Migrations::Converters::MarkdownEngine::Bundle do
  subject(:bundle) { described_class.load_or_build }

  let(:names) { bundle.entries.map(&:first) }

  it "loads the host's precompiled pretty-text bundle first" do
    expect(names.first).to eq("pretty-text.js")
    expect(bundle.entries.first.last).to include("__PrettyText")
  end

  it "contains the bundled plugins' vendored libraries" do
    expect(names).to include(a_string_matching(%r{node_modules/moment/moment\.js\z}))
  end

  it "contains the bundled plugins' markdown features" do
    expect(names).to include(
      a_string_matching(%r{\Adiscourse/plugins/poll/.*discourse-markdown/poll\z}),
    )
  end

  it "ends with the emoji table" do
    expect(names.last).to eq("migrations/emoji-data")
  end

  it "caches the built bundle on disk and reuses it" do
    bundle
    cache_dir =
      File.join(Migrations::Converters::MarkdownEngine.discourse_root, described_class::CACHE_DIR)
    cache_files = Dir[File.join(cache_dir, "markdown-engine-bundle-*.json")]
    expect(cache_files.size).to eq(1)

    # A rebuild from the warm cache must not transpile.
    allow(AssetProcessor).to receive(:new).and_call_original
    expect(described_class.load_or_build.entries.size).to eq(bundle.entries.size)
    expect(AssetProcessor).not_to have_received(:new)
  end

  it "builds a cold cache in a subprocess, leaving this process V8- and shim-free" do
    Dir.mktmpdir do |dir|
      cold = described_class.load_or_build(cache_dir: dir)

      expect(cold.entries.size).to eq(bundle.entries.size)
      # The whole point of the subprocess: the forking converter parent must
      # never initialize V8 (multithreaded V8 is not fork-safe) nor see the
      # Rails/Discourse stand-ins the transpiler needs.
      expect(AssetProcessor.booted?).to be(false)
      expect(defined?(::Rails)).to be_nil
      expect(defined?(::Discourse)).to be_nil

      cache_files = Dir[File.join(dir, "markdown-engine-bundle-*.json")]
      expect(cache_files.size).to eq(1)

      # A truncated cache (for example a partial copy) is a miss that
      # rebuilds, never a crash or trusted junk.
      File.write(cache_files.first, "{\"entries\": [[\"x\",")
      rebuilt = described_class.load_or_build(cache_dir: dir)
      expect(rebuilt.entries.size).to eq(bundle.entries.size)

      # Valid JSON with the wrong shape is a miss too; trusting it would
      # raise a NoMethodError later, in the context.
      File.write(cache_files.first, "{\"entries\": \"corrupt\"}")
      reshaped = described_class.load_or_build(cache_dir: dir)
      expect(reshaped.entries.size).to eq(bundle.entries.size)

      # An empty entry list can only come from a damaged file — no build
      # produces zero entries — so it is a miss, not a bundle with no engine.
      File.write(cache_files.first, "{\"entries\": []}")
      refilled = described_class.load_or_build(cache_dir: dir)
      expect(refilled.entries.size).to eq(bundle.entries.size)
    end
  end

  it "builds with a configured plugin list instead of the default set" do
    Dir.mktmpdir do |dir|
      custom = described_class.load_or_build(cache_dir: dir, plugins: %w[poll])
      custom_names = custom.entries.map(&:first)

      expect(custom_names).to include(
        a_string_matching(%r{\Adiscourse/plugins/poll/.*discourse-markdown/poll\z}),
      )
      expect(custom_names).not_to include(a_string_matching(%r{\Adiscourse/plugins/checklist/}))
      expect(custom.entries.size).to be < bundle.entries.size
    end
  end

  it "supports the production fork model: bundle in the parent, context in the worker" do
    # Run in a fresh ruby process so this spec process's own V8 contexts (other
    # examples build them) can't mask or break the property under test: a
    # parent that only loaded the bundle forks, and the worker builds a
    # working context.
    program = <<~RUBY
      require "migrations-converters"

      bundle = Migrations::Converters::MarkdownEngine::Bundle.load_or_build
      raise "parent booted V8" if AssetProcessor.booted?

      reader, writer = IO.pipe
      pid =
        fork do
          reader.close
          config = Migrations::Converters::MarkdownEngine::Config.new
          context = Migrations::Converters::MarkdownEngine::Context.new(bundle:, config:)
          result = context.scan([{ id: 1, raw: "hello @sam" }]).first
          writer.write(result["blocks"].first["mentions"].join(","))
          writer.close
          exit!(0)
        end
      writer.close
      output = reader.read
      Process.wait(pid)
      raise "worker scan failed: \#{output.inspect}" unless output == "@sam"
      puts "worker-scan-ok"
    RUBY

    stdout, stderr, status =
      Open3.capture3(
        RbConfig.ruby,
        "-e",
        program,
        chdir: Migrations::Converters::MarkdownEngine.discourse_root,
      )

    expect(status.success?).to be(true), stderr
    expect(stdout).to include("worker-scan-ok")
  end
end
