import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import Service from "@ember/service";
import { clearRender, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dSelect from "discourse/tests/helpers/d-select-helper";
import { i18n } from "discourse-i18n";
import LiveVideoSettingsModal from "discourse/plugins/live/discourse/components/modal/live-video-settings";

const CAMERA = ".live-video-settings__camera-select";
const CAMERA_QUALITY = ".live-video-settings__camera-quality-select";
const SCREEN_QUALITY = ".live-video-settings__screen-quality-select";
const SCREEN_CONTENT = ".live-video-settings__screen-content-select";

class LiveWebrtcStub extends Service {
  @tracked videoInputDeviceId = "system_default";
  @tracked cameraQuality = "standard";
  @tracked screenContent = "motion";
  @tracked screenQuality = "standard";

  localVideoKind = null;
  videoBlurAmount = 0;
  videoBlurAvailable = false;
  videoBlurEnabled = false;
  videoBlurSupported = false;
  cameraQualityTiers = ["standard"];
  screenQualityTiers = ["standard"];
  cameraPicks = [];
  cameraQualityPicks = [];
  screenContentPicks = [];
  screenQualityPicks = [];

  allowedCameraQualityTiers() {
    return this.cameraQualityTiers;
  }

  allowedScreenQualityTiers() {
    return this.screenQualityTiers;
  }

  @action
  setCameraQuality(tier) {
    this.cameraQualityPicks.push(tier);
    this.cameraQuality = tier;
  }

  @action
  setScreenContent(content) {
    this.screenContentPicks.push(content);
    this.screenContent = content;
  }

  @action
  setScreenQuality(tier) {
    this.screenQualityPicks.push(tier);
    this.screenQuality = tier;
  }

  attachVideoStream() {}

  effectiveCameraQuality() {
    return "standard";
  }

  async setVideoInputDevice(deviceId) {
    this.cameraPicks.push(deviceId);
    this.videoInputDeviceId = deviceId;
  }
}

module("Integration | Component | LiveVideoSettingsModal", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.siteSettings.enable_new_select_controls = true;
    this.owner.unregister("service:live-webrtc");
    this.owner.register("service:live-webrtc", LiveWebrtcStub);
    this.liveWebrtc = this.owner.lookup("service:live-webrtc");

    this.devices = [
      { kind: "videoinput", deviceId: "desk-cam", label: "Desk camera" },
      { kind: "audioinput", deviceId: "desk-mic", label: "Desk mic" },
    ];
    sinon
      .stub(navigator.mediaDevices, "enumerateDevices")
      .callsFake(async () => this.devices);
    sinon
      .stub(navigator.mediaDevices, "getUserMedia")
      .resolves(new MediaStream());
  });

  test("lists the cameras", async function (assert) {
    await render(
      <template><LiveVideoSettingsModal @inline={{true}} /></template>
    );

    await dSelect(CAMERA).open();

    assert
      .dSelect(CAMERA)
      .hasOptions(
        ["system_default", "desk-cam"],
        "the system default comes first, then the browser's cameras"
      );
  });

  test("switches the camera when one is picked", async function (assert) {
    await render(
      <template><LiveVideoSettingsModal @inline={{true}} /></template>
    );

    await dSelect(CAMERA).open();
    await dSelect(CAMERA).select("desk-cam");

    assert.deepEqual(
      this.liveWebrtc.cameraPicks,
      ["desk-cam"],
      "the picked camera is handed to the call"
    );
  });

  test("lists the cameras even when the camera can't be opened", async function (assert) {
    navigator.mediaDevices.getUserMedia.rejects(new Error("denied"));

    await render(
      <template><LiveVideoSettingsModal @inline={{true}} /></template>
    );

    await dSelect(CAMERA).open();

    assert
      .dSelect(CAMERA)
      .hasOptions(
        ["system_default", "desk-cam"],
        "a failed preview still loads the camera list"
      );
  });

  test("refreshes the open list when a camera is plugged in", async function (assert) {
    await render(
      <template><LiveVideoSettingsModal @inline={{true}} /></template>
    );

    await dSelect(CAMERA).open();

    this.devices = [
      ...this.devices,
      { kind: "videoinput", deviceId: "webcam", label: "Webcam" },
    ];
    navigator.mediaDevices.dispatchEvent(new Event("devicechange"));
    await settled();

    assert
      .dSelect(CAMERA)
      .hasOptions(
        ["system_default", "desk-cam", "webcam"],
        "the new camera joins the list while it is open"
      );
  });

  test("picks a camera quality", async function (assert) {
    this.liveWebrtc.cameraQualityTiers = ["standard", "high"];
    await render(
      <template><LiveVideoSettingsModal @inline={{true}} /></template>
    );

    assert
      .dSelect(CAMERA_QUALITY)
      .hasName(
        i18n("live.quality.standard"),
        "the trigger names the current camera quality"
      );

    await dSelect(CAMERA_QUALITY).open();

    assert
      .dSelect(CAMERA_QUALITY)
      .hasOptions(
        ["standard", "high"],
        "the camera quality choices are offered"
      );

    await dSelect(CAMERA_QUALITY).select("high");

    assert.deepEqual(
      this.liveWebrtc.cameraQualityPicks,
      ["high"],
      "the picked camera quality is handed to the call"
    );
  });

  test("picks a screen quality", async function (assert) {
    this.liveWebrtc.screenQualityTiers = ["standard", "maximum"];
    await render(
      <template><LiveVideoSettingsModal @inline={{true}} /></template>
    );

    assert
      .dSelect(SCREEN_QUALITY)
      .hasName(
        i18n("live.quality.standard"),
        "the trigger names the current screen quality"
      );

    await dSelect(SCREEN_QUALITY).open();

    assert
      .dSelect(SCREEN_QUALITY)
      .hasOptions(
        ["standard", "maximum"],
        "the screen quality choices are offered"
      );

    await dSelect(SCREEN_QUALITY).select("maximum");

    assert.deepEqual(
      this.liveWebrtc.screenQualityPicks,
      ["maximum"],
      "the picked screen quality is handed to the call"
    );
  });

  test("picks what a shared screen shows", async function (assert) {
    await render(
      <template><LiveVideoSettingsModal @inline={{true}} /></template>
    );

    assert
      .dSelect(SCREEN_CONTENT)
      .hasName(
        i18n("live.video_settings.screen_content_motion"),
        "the trigger names the current screen content"
      );

    await dSelect(SCREEN_CONTENT).open();

    assert
      .dSelect(SCREEN_CONTENT)
      .hasOptions(["text", "motion"], "the screen content choices are offered");

    await dSelect(SCREEN_CONTENT).select("text");

    assert.deepEqual(
      this.liveWebrtc.screenContentPicks,
      ["text"],
      "the picked screen content is handed to the call"
    );
  });

  test("names a held camera by the name it had when it was last connected", async function (assert) {
    localStorage.setItem("voice_video_input_device", "desk-cam");
    this.liveWebrtc.videoInputDeviceId = "desk-cam";
    await render(
      <template><LiveVideoSettingsModal @inline={{true}} /></template>
    );
    await clearRender();

    this.devices = this.devices.filter(
      (device) => device.deviceId !== "desk-cam"
    );
    await render(
      <template><LiveVideoSettingsModal @inline={{true}} /></template>
    );

    assert
      .dSelect(CAMERA)
      .hasName("Desk camera", "the unplugged camera keeps its last known name");
  });
});
