# frozen_string_literal: true

RSpec.describe Migrations::Converters::MarkdownEngine::Bundle do
  subject(:bundle) { described_class.load_or_build }

  let(:names) { bundle.entries.map(&:first) }

  it "loads the vendor libraries first" do
    expect(names.first).to end_with("loader.js")
  end

  it "contains the engine and pretty-text modules" do
    expect(names).to include("discourse-markdown-it/index", "pretty-text/text-replace")
  end

  it "contains the bundled plugins' markdown features" do
    expect(names).to include(
      a_string_matching(%r{\Adiscourse/plugins/poll/.*discourse-markdown/poll\z}),
    )
  end

  it "ends with the host shims and the emoji table" do
    expect(names.last(2)).to eq([described_class::SHIMS_FILE, "migrations/emoji-data"])
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
end
