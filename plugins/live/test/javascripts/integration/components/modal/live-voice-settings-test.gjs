import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import Service from "@ember/service";
import { clearRender, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dSelect from "discourse/tests/helpers/d-select-helper";
import { i18n } from "discourse-i18n";
import LiveVoiceSettingsModal from "discourse/plugins/live/discourse/components/modal/live-voice-settings";
import { NOISE_SUPPRESSION_MODES } from "discourse/plugins/live/discourse/lib/live/audio-processing";

const INPUT = ".live-voice-settings__input-select";
const OUTPUT = ".live-voice-settings__output-select";
const NOISE_SUPPRESSION = ".live-voice-settings__noise-suppression-select";
const SUBTITLES_MODEL = ".live-voice-settings__subtitles-model-select";
const QUALITY = ".live-voice-settings__quality-select";

class LiveWebrtcStub extends Service {
  @tracked inputDeviceId = "system_default";

  @tracked outputDeviceId = "system_default";
  @tracked noiseSuppressionMode = "standard";
  @tracked sttModel = "ultra";
  @tracked voiceQuality = "standard";
  autoGainControl = true;
  echoCancellation = true;
  gateThreshold = 0;
  noiseSuppressionState = "idle";

  subtitlesAvailable = false;
  subtitlesEnabled = false;
  voiceQualityTiers = ["standard"];
  inputDevicePicks = [];
  noiseSuppressionPicks = [];
  outputDevicePicks = [];
  sttModelPicks = [];
  voiceQualityPicks = [];

  allowedVoiceQualityTiers() {
    return this.voiceQualityTiers;
  }

  setNoiseSuppressionMode(mode) {
    this.noiseSuppressionPicks.push(mode);
    this.noiseSuppressionMode = mode;
  }

  @action
  setSttModel(model) {
    this.sttModelPicks.push(model);
    this.sttModel = model;
  }

  @action
  setVoiceQuality(tier) {
    this.voiceQualityPicks.push(tier);
    this.voiceQuality = tier;
  }

  async setInputDevice(deviceId) {
    this.inputDevicePicks.push(deviceId);
    this.inputDeviceId = deviceId;
  }

  setOutputDevice(deviceId) {
    this.outputDevicePicks.push(deviceId);
    this.outputDeviceId = deviceId;
  }
}

module("Integration | Component | LiveVoiceSettingsModal", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.siteSettings.enable_new_select_controls = true;
    this.owner.unregister("service:live-webrtc");
    this.owner.register("service:live-webrtc", LiveWebrtcStub);
    this.liveWebrtc = this.owner.lookup("service:live-webrtc");

    this.devices = [
      { kind: "audioinput", deviceId: "desk-mic", label: "Desk mic" },
      { kind: "audiooutput", deviceId: "speakers", label: "Speakers" },
    ];
    this.listing = Promise.withResolvers();
    sinon
      .stub(navigator.mediaDevices, "enumerateDevices")
      .callsFake(() => this.listing.promise.then(() => this.devices));
    sinon
      .stub(navigator.mediaDevices, "getUserMedia")
      .resolves(new MediaStream());
  });

  test("lists the devices even when the microphone can't be opened", async function (assert) {
    navigator.mediaDevices.getUserMedia.rejects(new Error("denied"));
    this.listing.resolve();

    await render(
      <template><LiveVoiceSettingsModal @inline={{true}} /></template>
    );

    await dSelect(INPUT).open();

    assert
      .dSelect(INPUT)
      .hasOptions(
        ["system_default", "desk-mic"],
        "a failed preview still loads the device list"
      );
  });

  test("refreshes the open list when a device is plugged in", async function (assert) {
    this.listing.resolve();
    await render(
      <template><LiveVoiceSettingsModal @inline={{true}} /></template>
    );

    await dSelect(INPUT).open();

    this.devices = [
      ...this.devices,
      { kind: "audioinput", deviceId: "headset", label: "Headset" },
    ];
    navigator.mediaDevices.dispatchEvent(new Event("devicechange"));
    await settled();

    assert
      .dSelect(INPUT)
      .hasOptions(
        ["system_default", "desk-mic", "headset"],
        "the new device joins the list while it is open"
      );
  });

  test("switches the input when a device is picked", async function (assert) {
    this.listing.resolve();
    await render(
      <template><LiveVoiceSettingsModal @inline={{true}} /></template>
    );

    await dSelect(INPUT).open();
    await dSelect(INPUT).select("desk-mic");

    assert.deepEqual(
      this.liveWebrtc.inputDevicePicks,
      ["desk-mic"],
      "the picked device is handed to the call"
    );
  });

  test("lists the output devices", async function (assert) {
    this.listing.resolve();
    await render(
      <template><LiveVoiceSettingsModal @inline={{true}} /></template>
    );

    await dSelect(OUTPUT).open();

    assert
      .dSelect(OUTPUT)
      .hasOptions(
        ["system_default", "speakers"],
        "the system default comes first, then the browser's outputs"
      );
  });

  test("switches the output when a device is picked", async function (assert) {
    this.listing.resolve();
    await render(
      <template><LiveVoiceSettingsModal @inline={{true}} /></template>
    );

    await dSelect(OUTPUT).open();
    await dSelect(OUTPUT).select("speakers");

    assert.deepEqual(
      this.liveWebrtc.outputDevicePicks,
      ["speakers"],
      "the picked output is handed to the call"
    );
  });

  test("marks a remembered output that isn't connected as unavailable", async function (assert) {
    this.liveWebrtc.outputDeviceId = "unplugged-speakers";
    this.listing.resolve();

    await render(
      <template><LiveVoiceSettingsModal @inline={{true}} /></template>
    );

    assert
      .dom(OUTPUT)
      .hasAttribute(
        "data-name",
        i18n("live.devices.missing_device"),
        "an output the browser never named reads as unknown"
      );
    assert
      .dom(`${OUTPUT} .d-pill`)
      .hasText(
        i18n("live.devices.unavailable"),
        "the trigger marks it unavailable"
      );
  });

  test("picks a noise suppression mode", async function (assert) {
    this.listing.resolve();
    await render(
      <template><LiveVoiceSettingsModal @inline={{true}} /></template>
    );

    assert
      .dSelect(NOISE_SUPPRESSION)
      .hasName(
        i18n("live.voice_settings.noise_suppression_modes.standard"),
        "the trigger names the current mode"
      );

    await dSelect(NOISE_SUPPRESSION).open();

    assert
      .dSelect(NOISE_SUPPRESSION)
      .hasOptions(NOISE_SUPPRESSION_MODES, "every mode is offered");

    const rnnoise = ".d-select__option[data-value='ai:rnnoise']";
    assert
      .dom(`${rnnoise} .d-select__option-content > span:first-child`)
      .hasText(
        i18n("live.voice_settings.noise_suppression_ai_modes.ai_rnnoise.name"),
        "an AI mode is named by its engine"
      );
    assert
      .dom(`${rnnoise} .d-select__option-description`)
      .hasText(
        i18n(
          "live.voice_settings.noise_suppression_ai_modes.ai_rnnoise.description"
        ),
        "and describes its trade-off"
      );

    await dSelect(NOISE_SUPPRESSION).select("none");

    assert.deepEqual(
      this.liveWebrtc.noiseSuppressionPicks,
      ["none"],
      "the picked mode is handed to the call"
    );
  });

  test("locks the noise suppression mode while one is starting", async function (assert) {
    this.liveWebrtc.noiseSuppressionState = "starting";
    this.listing.resolve();
    await render(
      <template><LiveVoiceSettingsModal @inline={{true}} /></template>
    );

    assert
      .dSelect(NOISE_SUPPRESSION)
      .isDisabled("the mode can't change until the current one starts");
  });

  test("picks a subtitles model", async function (assert) {
    this.liveWebrtc.subtitlesAvailable = true;
    this.listing.resolve();
    await render(
      <template><LiveVoiceSettingsModal @inline={{true}} /></template>
    );

    assert
      .dSelect(SUBTITLES_MODEL)
      .hasName(
        i18n("live.voice_settings.subtitles_models.ultra"),
        "the trigger names the current model"
      );

    await dSelect(SUBTITLES_MODEL).open();

    assert
      .dSelect(SUBTITLES_MODEL)
      .hasOptions(["ultra", "redux"], "every model is offered");

    await dSelect(SUBTITLES_MODEL).select("redux");

    assert.deepEqual(
      this.liveWebrtc.sttModelPicks,
      ["redux"],
      "the picked model is handed to the call"
    );
  });

  test("picks a voice quality", async function (assert) {
    this.liveWebrtc.voiceQualityTiers = ["standard", "high"];
    this.listing.resolve();
    await render(
      <template><LiveVoiceSettingsModal @inline={{true}} /></template>
    );

    assert
      .dSelect(QUALITY)
      .hasName(
        i18n("live.quality.standard"),
        "the trigger names the current quality"
      );

    await dSelect(QUALITY).open();

    assert
      .dSelect(QUALITY)
      .hasOptions(["standard", "high"], "the allowed qualities are offered");

    await dSelect(QUALITY).select("high");

    assert.deepEqual(
      this.liveWebrtc.voiceQualityPicks,
      ["high"],
      "the picked quality is handed to the call"
    );
  });

  test("names a held device by the name it had when it was last connected", async function (assert) {
    localStorage.setItem("voice_audio_input_device", "desk-mic");
    this.liveWebrtc.inputDeviceId = "desk-mic";
    this.listing.resolve();
    await render(
      <template><LiveVoiceSettingsModal @inline={{true}} /></template>
    );
    await clearRender();

    this.devices = this.devices.filter(
      (device) => device.deviceId !== "desk-mic"
    );
    await render(
      <template><LiveVoiceSettingsModal @inline={{true}} /></template>
    );

    assert
      .dSelect(INPUT)
      .hasName("Desk mic", "the unplugged device keeps its last known name");
    assert
      .dom(`${INPUT} .d-pill`)
      .hasText(
        i18n("live.devices.unavailable"),
        "and is still marked unavailable"
      );
  });

  test("names a held microphone after itself, not a speaker sharing its id", async function (assert) {
    // Browsers give both kinds' default entries the id "default".
    this.devices = [
      { kind: "audiooutput", deviceId: "default", label: "Default - Speakers" },
      { kind: "audioinput", deviceId: "default", label: "Default - Desk mic" },
    ];
    localStorage.setItem("voice_audio_input_device", "default");
    this.liveWebrtc.inputDeviceId = "default";
    this.listing.resolve();
    await render(
      <template><LiveVoiceSettingsModal @inline={{true}} /></template>
    );
    await clearRender();

    this.devices = this.devices.filter(
      (device) => device.kind !== "audioinput"
    );
    await render(
      <template><LiveVoiceSettingsModal @inline={{true}} /></template>
    );

    assert
      .dSelect(INPUT)
      .hasName("Default - Desk mic", "the microphone keeps its own name");
  });
});
