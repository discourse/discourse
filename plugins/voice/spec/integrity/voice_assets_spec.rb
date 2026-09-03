# frozen_string_literal: true

# The heavyweight browser assets (wasm engines, ML models, SDK bundles) live
# in the discourse_voice_assets gem under stable filenames; the plugin mounts
# the gem's vendor tree at a gem-version-stamped public path and hardcodes
# those filenames in its loaders. These specs pin that contract: every file
# the client references must exist in the gem, and the versioned mount must
# be in place.
RSpec.describe "discourse_voice_assets integrity" do
  # Keep in sync with the loaders: subtitles.js, ns-engines.js,
  # background-blur.js, livekit-session.js.
  CLIENT_REFERENCED_ASSETS = %w[
    dfn3/dfn3-worklet.js
    dfn3/dfn3.wasm
    dfn3/dfn3-model.bin
    dtln/dtln-worklet.js
    dtln/dtln.wasm
    rnnoise/rnnoise-worklet.js
    rnnoise/rnnoise.wasm
    stt/subtitles-worker.js
    stt/vad.js
    stt/ort/ort-wasm-simd-threaded.jsep.js
    stt/ort/ort-wasm-simd-threaded.jsep.wasm
    stt/vad/
    livekit/livekit-client.js
    mediapipe/vision_bundle.js
    mediapipe/selfie_segmenter.tflite
    mediapipe/wasm/
  ]

  CLIENT_REFERENCED_ASSETS.each do |file|
    it "finds #{file} in the gem's vendor tree" do
      path = DiscourseVoiceAssets.vendor_path(file)
      exists = file.end_with?("/") ? File.directory?(path) : File.exist?(path)
      expect(exists).to be(true), "gem asset missing: #{file}"
    end
  end

  it "mounts the gem's vendor tree at the version-stamped public path" do
    link = File.expand_path("../../public/javascripts/#{DiscourseVoiceAssets::VERSION}", __dir__)
    expect(File.symlink?(link)).to be(true), "missing symlink: #{link}"
    expect(File.readlink(link)).to eq(DiscourseVoiceAssets.vendor_path)
  end

  it "serializes the versioned base path the client builds URLs from" do
    SiteSetting.voice_enabled = true
    guardian = Guardian.new
    serialized = SiteSerializer.new(Site.new(guardian), scope: guardian, root: false).as_json
    expect(serialized[:voice_assets_path]).to eq(
      "/plugins/voice/javascripts/#{DiscourseVoiceAssets::VERSION}",
    )
  end
end
