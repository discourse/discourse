# frozen_string_literal: true

RSpec.describe PrecompiledBundle do
  let(:root) { "tmp/precompiled_bundle_spec_#{SecureRandom.hex(4)}" }
  let(:source_path) { Rails.root.join(root, "src/source.js") }
  let(:builds) { [] }
  let(:bundle) do
    described_class.new(
      dir: "#{root}/out",
      filename_prefix: "bundle",
      dependency_globs: ["#{root}/src/*.js"],
    ) do
      builds << File.read(source_path)
      "built from #{builds.last}"
    end
  end

  before do
    FileUtils.mkdir_p(File.dirname(source_path))
    File.write(source_path, "v1")

    # The build is a plain block, so it doesn't need the installed node_modules
    allow(bundle).to receive(:verify_node_modules!)
  end

  after { FileUtils.rm_rf(Rails.root.join(root)) }

  describe "#load_or_build" do
    it "builds once and records the digest of the cached source" do
      2.times { expect(bundle.load_or_build).to eq("built from v1") }

      expect(builds).to eq(["v1"])
      expect(bundle.path.basename.to_s).to eq("bundle-#{bundle.loaded_digest}.js")
    end

    it "rebuilds and replaces the cached source when a dependency changes" do
      bundle.load_or_build
      first_digest = bundle.loaded_digest

      File.write(source_path, "v2")

      expect(bundle.load_or_build).to eq("built from v2")
      expect(bundle.loaded_digest).not_to eq(first_digest)
      expect(Dir.glob("bundle-*.js", base: Rails.root.join(root, "out"))).to contain_exactly(
        bundle.path.basename.to_s,
      )
    end
  end
end
