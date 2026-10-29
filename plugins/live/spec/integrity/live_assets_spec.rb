# frozen_string_literal: true

# The heavyweight browser assets (wasm engines, ML models, SDK bundles) live
# in the discourse_voice_assets gem under stable filenames; the plugin mounts
# the gem's vendor tree at a gem-version-stamped public path and hardcodes
# those filenames in its loaders. These specs pin that contract: every file
# the client references must exist in the gem, and the versioned mount must
# be in place.
RSpec.describe "discourse_voice_assets integrity" do
  shared_examples "live assets for file" do |file|
    it "finds #{file} in the gem's vendor tree" do
      path = DiscourseVoiceAssets.vendor_path(file)
      exists = file.end_with?("/") ? File.directory?(path) : File.exist?(path)
      expect(exists).to be(true), "gem asset missing: #{file}"
    end
  end

  # Keep in sync with the loaders: subtitles.js, ns-engines.js,
  # background-blur.js, livekit-session.js.
  include_examples "live assets for file", "dfn3/dfn3-worklet.js"
  include_examples "live assets for file", "dfn3/dfn3.wasm"
  include_examples "live assets for file", "dfn3/dfn3-model.bin"
  include_examples "live assets for file", "dtln/dtln-worklet.js"
  include_examples "live assets for file", "dtln/dtln.wasm"
  include_examples "live assets for file", "rnnoise/rnnoise-worklet.js"
  include_examples "live assets for file", "rnnoise/rnnoise.wasm"
  include_examples "live assets for file", "stt/subtitles-worker.js"
  include_examples "live assets for file", "stt/vad.js"
  include_examples "live assets for file", "stt/ort/ort-wasm-simd-threaded.asyncify.js"
  include_examples "live assets for file", "stt/ort/ort-wasm-simd-threaded.asyncify.wasm"
  include_examples "live assets for file", "stt/vad/"
  include_examples "live assets for file", "livekit/livekit-client.js"
  include_examples "live assets for file", "mediapipe/vision_bundle.js"
  include_examples "live assets for file", "mediapipe/selfie_segmenter.tflite"
  include_examples "live assets for file", "mediapipe/wasm/"

  it "mounts the gem's vendor tree at the version-stamped public path" do
    link = File.expand_path("../../public/javascripts/#{DiscourseVoiceAssets::VERSION}", __dir__)
    expect(File.symlink?(link)).to be(true), "missing symlink: #{link}"
    expect(File.readlink(link)).to eq(DiscourseVoiceAssets.vendor_path)
  end

  it "serializes the versioned base path the client builds URLs from" do
    SiteSetting.live_enabled = true
    guardian = Guardian.new
    serialized = SiteSerializer.new(Site.new(guardian), scope: guardian, root: false).as_json
    expect(serialized[:live_assets_path]).to eq(
      "/plugins/live/javascripts/#{DiscourseVoiceAssets::VERSION}",
    )
  end
end
