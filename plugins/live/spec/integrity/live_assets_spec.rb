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
  it "finds dfn3/dfn3-worklet.js in the gem's vendor tree" do
    path = DiscourseVoiceAssets.vendor_path("dfn3/dfn3-worklet.js")
    exists = File.exist?(path)
    expect(exists).to be(true), "gem asset missing: dfn3/dfn3-worklet.js"
  end

  it "finds dfn3/dfn3.wasm in the gem's vendor tree" do
    path = DiscourseVoiceAssets.vendor_path("dfn3/dfn3.wasm")
    exists = File.exist?(path)
    expect(exists).to be(true), "gem asset missing: dfn3/dfn3.wasm"
  end

  it "finds dfn3/dfn3-model.bin in the gem's vendor tree" do
    path = DiscourseVoiceAssets.vendor_path("dfn3/dfn3-model.bin")
    exists = File.exist?(path)
    expect(exists).to be(true), "gem asset missing: dfn3/dfn3-model.bin"
  end

  it "finds dtln/dtln-worklet.js in the gem's vendor tree" do
    path = DiscourseVoiceAssets.vendor_path("dtln/dtln-worklet.js")
    exists = File.exist?(path)
    expect(exists).to be(true), "gem asset missing: dtln/dtln-worklet.js"
  end

  it "finds dtln/dtln.wasm in the gem's vendor tree" do
    path = DiscourseVoiceAssets.vendor_path("dtln/dtln.wasm")
    exists = File.exist?(path)
    expect(exists).to be(true), "gem asset missing: dtln/dtln.wasm"
  end

  it "finds rnnoise/rnnoise-worklet.js in the gem's vendor tree" do
    path = DiscourseVoiceAssets.vendor_path("rnnoise/rnnoise-worklet.js")
    exists = File.exist?(path)
    expect(exists).to be(true), "gem asset missing: rnnoise/rnnoise-worklet.js"
  end

  it "finds rnnoise/rnnoise.wasm in the gem's vendor tree" do
    path = DiscourseVoiceAssets.vendor_path("rnnoise/rnnoise.wasm")
    exists = File.exist?(path)
    expect(exists).to be(true), "gem asset missing: rnnoise/rnnoise.wasm"
  end

  it "finds stt/subtitles-worker.js in the gem's vendor tree" do
    path = DiscourseVoiceAssets.vendor_path("stt/subtitles-worker.js")
    exists = File.exist?(path)
    expect(exists).to be(true), "gem asset missing: stt/subtitles-worker.js"
  end

  it "finds stt/vad.js in the gem's vendor tree" do
    path = DiscourseVoiceAssets.vendor_path("stt/vad.js")
    exists = File.exist?(path)
    expect(exists).to be(true), "gem asset missing: stt/vad.js"
  end

  it "finds stt/ort/ort-wasm-simd-threaded.asyncify.js in the gem's vendor tree" do
    path = DiscourseVoiceAssets.vendor_path("stt/ort/ort-wasm-simd-threaded.asyncify.js")
    exists = File.exist?(path)
    expect(exists).to be(true), "gem asset missing: stt/ort/ort-wasm-simd-threaded.asyncify.js"
  end

  it "finds stt/ort/ort-wasm-simd-threaded.asyncify.wasm in the gem's vendor tree" do
    path = DiscourseVoiceAssets.vendor_path("stt/ort/ort-wasm-simd-threaded.asyncify.wasm")
    exists = File.exist?(path)
    expect(exists).to be(true), "gem asset missing: stt/ort/ort-wasm-simd-threaded.asyncify.wasm"
  end

  it "finds stt/vad/ in the gem's vendor tree" do
    path = DiscourseVoiceAssets.vendor_path("stt/vad/")
    exists = File.directory?(path)
    expect(exists).to be(true), "gem asset missing: stt/vad/"
  end

  it "finds livekit/livekit-client.js in the gem's vendor tree" do
    path = DiscourseVoiceAssets.vendor_path("livekit/livekit-client.js")
    exists = File.exist?(path)
    expect(exists).to be(true), "gem asset missing: livekit/livekit-client.js"
  end

  it "finds mediapipe/vision_bundle.js in the gem's vendor tree" do
    path = DiscourseVoiceAssets.vendor_path("mediapipe/vision_bundle.js")
    exists = File.exist?(path)
    expect(exists).to be(true), "gem asset missing: mediapipe/vision_bundle.js"
  end

  it "finds mediapipe/selfie_segmenter.tflite in the gem's vendor tree" do
    path = DiscourseVoiceAssets.vendor_path("mediapipe/selfie_segmenter.tflite")
    exists = File.exist?(path)
    expect(exists).to be(true), "gem asset missing: mediapipe/selfie_segmenter.tflite"
  end

  it "finds mediapipe/wasm/ in the gem's vendor tree" do
    path = DiscourseVoiceAssets.vendor_path("mediapipe/wasm/")
    exists = File.directory?(path)
    expect(exists).to be(true), "gem asset missing: mediapipe/wasm/"
  end

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
